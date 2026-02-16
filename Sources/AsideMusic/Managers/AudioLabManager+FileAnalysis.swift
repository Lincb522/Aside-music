// AudioLabManager+FileAnalysis.swift
// AsideMusic
//
// 文件分析：使用 SDK AudioAnalyzer.analyzeFile 进行完整音频分析

import Foundation
import FFmpegSwiftSDK

extension AudioLabManager {
    
    // MARK: - 文件分析（使用 SDK 的 AudioAnalyzer.analyzeFile）
    
    /// 从音频文件进行完整分析
    func analyzeFromFile(url: String) async throws -> AudioAnalysisResult {
        AppLogger.info("开始文件分析: \(url)")
        
        let sdkResult = try await AudioAnalyzer.analyzeFile(
            url: url,
            maxDuration: 60,
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    self?.analysisProgress = 0.4 + progress * 0.45
                }
            }
        )
        
        analysisProgress = 0.9
        
        let genre = inferGenreFromSDKResult(sdkResult)
        let timbre = convertTimbreAnalysis(sdkResult.timbre)
        let quality = convertQualityAssessment(sdkResult)
        
        analysisProgress = 0.92
        
        let recommendedEffects = generateRecommendedEffectsFromSDK(
            sdkResult: sdkResult,
            genre: genre
        )
        
        analysisProgress = 0.95
        
        return AudioAnalysisResult(
            bpm: sdkResult.bpm.bpm,
            bpmConfidence: sdkResult.bpm.confidence,
            loudness: sdkResult.loudness.integratedLUFS,
            dynamicRange: Float(sdkResult.dynamicRange.drValue),
            spectralCentroid: sdkResult.frequency.spectralCentroid,
            lowFrequencyRatio: sdkResult.frequency.lowEnergyRatio,
            midFrequencyRatio: sdkResult.frequency.midEnergyRatio,
            highFrequencyRatio: sdkResult.frequency.highEnergyRatio,
            suggestedGenre: genre,
            recommendedPresetId: getRecommendedPreset(for: genre),
            recommendedEffects: recommendedEffects,
            timbreAnalysis: timbre,
            qualityAssessment: quality
        )
    }

    /// 从 SDK 分析结果推断音乐类型
    func inferGenreFromSDKResult(_ result: AudioAnalyzer.FullAnalysisResult) -> SuggestedGenre {
        let bpm = result.bpm.bpm
        let freq = result.frequency
        let dynamic = result.dynamicRange
        
        if freq.lowEnergyRatio > 0.4 && freq.midEnergyRatio < 0.35 {
            return bpm > 120 ? .electronic : .hiphop
        }
        if freq.midEnergyRatio > 0.45 {
            return freq.spectralCentroid > 2000 ? .vocal : .acoustic
        }
        if freq.highEnergyRatio > 0.35 && dynamic.drValue >= 10 {
            return freq.spectralCentroid > 3000 ? .classical : .jazz
        }
        if bpm > 130 && freq.lowEnergyRatio > 0.35 {
            return dynamic.drValue < 8 ? .metal : .rock
        }
        if bpm > 110 {
            return freq.lowEnergyRatio > 0.35 ? .rock : .pop
        }
        if freq.lowEnergyRatio > 0.35 && bpm < 100 {
            return .rnb
        }
        return .pop
    }
    
    /// 转换 SDK 的音色分析结果
    func convertTimbreAnalysis(_ sdkTimbre: AudioAnalyzer.TimbreAnalysis) -> TimbreInfo {
        return TimbreInfo(
            brightness: sdkTimbre.brightness,
            warmth: sdkTimbre.warmth,
            clarity: sdkTimbre.clarity,
            fullness: sdkTimbre.fullness,
            description: sdkTimbre.description,
            eqSuggestion: sdkTimbre.eqSuggestion
        )
    }
    
    /// 转换 SDK 的质量评估结果
    func convertQualityAssessment(_ sdkResult: AudioAnalyzer.FullAnalysisResult) -> QualityInfo {
        let dynamic = sdkResult.dynamicRange
        let clipping = sdkResult.clipping
        
        var issues: [String] = []
        var dynamicScore = 100
        var frequencyScore = 100
        
        if dynamic.drValue < 6 {
            dynamicScore -= 40
            issues.append("动态范围过窄（DR\(dynamic.drValue)）")
        } else if dynamic.drValue < 10 {
            dynamicScore -= 20
        }
        
        if clipping.hasSevereClipping {
            dynamicScore -= 30
            issues.append("存在严重削波")
        }
        
        let freq = sdkResult.frequency
        if freq.lowEnergyRatio > 0.6 {
            frequencyScore -= 20
            issues.append("低频过重")
        } else if freq.lowEnergyRatio < 0.1 {
            frequencyScore -= 15
            issues.append("低频不足")
        }
        
        if freq.highEnergyRatio > 0.5 {
            frequencyScore -= 15
            issues.append("高频过亮")
        }
        
        let overallScore = (dynamicScore + frequencyScore) / 2
        let grade: String
        if overallScore >= 90 { grade = "优秀" }
        else if overallScore >= 75 { grade = "良好" }
        else if overallScore >= 60 { grade = "一般" }
        else { grade = "较差" }
        
        return QualityInfo(
            overallScore: overallScore,
            dynamicScore: dynamicScore,
            frequencyScore: frequencyScore,
            grade: grade,
            issues: issues
        )
    }

    /// 基于 SDK 完整分析结果生成推荐音效参数
    func generateRecommendedEffectsFromSDK(
        sdkResult: AudioAnalyzer.FullAnalysisResult,
        genre: SuggestedGenre
    ) -> RecommendedEffects {
        let freq = sdkResult.frequency
        let timbre = sdkResult.timbre
        let dynamic = sdkResult.dynamicRange
        let loudness = sdkResult.loudness
        
        // ═══════════════════════════════════════
        // 智能 EQ 生成算法（基于完整频率分析）
        // ═══════════════════════════════════════
        
        var eqGains: [Float] = Array(repeating: 0, count: 10)
        
        let idealLow: Float = 0.30
        let idealMid: Float = 0.40
        let idealHigh: Float = 0.30
        
        let lowDiff = idealLow - freq.lowEnergyRatio
        let midDiff = idealMid - freq.midEnergyRatio
        let highDiff = idealHigh - freq.highEnergyRatio
        
        let lowBoost = lowDiff * 18
        eqGains[0] = clampGain(lowBoost * 0.7)
        eqGains[1] = clampGain(lowBoost * 1.0)
        eqGains[2] = clampGain(lowBoost * 0.85)
        eqGains[3] = clampGain(lowBoost * 0.3 + midDiff * 0.4)
        
        let midBoost = midDiff * 14
        eqGains[4] = clampGain(midBoost * 0.6)
        eqGains[5] = clampGain(midBoost * 1.0)
        eqGains[6] = clampGain(midBoost * 0.85)
        
        let highBoost = highDiff * 18
        eqGains[7] = clampGain(highBoost * 0.6 + midBoost * 0.2)
        eqGains[8] = clampGain(highBoost * 1.0)
        eqGains[9] = clampGain(highBoost * 0.75)
        
        let centroidTarget: Float = 2200
        let brightnessAdjust = clampGain((centroidTarget - freq.spectralCentroid) / 400)
        eqGains[7] += brightnessAdjust * 0.25
        eqGains[8] += brightnessAdjust * 0.4
        eqGains[9] += brightnessAdjust * 0.3
        
        for i in 0..<10 {
            eqGains[i] = clampGain(eqGains[i])
        }

        // ═══════════════════════════════════════
        // 智能音效参数生成（基于完整分析）
        // ═══════════════════════════════════════
        
        var bassGain: Float = lowDiff * 10
        var trebleGain: Float = highDiff * 10
        
        var surroundLevel: Float = 0.2 + freq.lowEnergyRatio * 0.3
        if let phase = sdkResult.phase {
            if phase.stereoWidth < 0.3 {
                surroundLevel += 0.2
            }
        }
        
        var reverbLevel: Float = 0.1 + freq.highEnergyRatio * 0.25
        if dynamic.drValue >= 12 {
            reverbLevel += 0.15
        }
        
        let balance = 1.0 - abs(freq.lowEnergyRatio - freq.highEnergyRatio)
        var stereoWidth: Float = 1.0 + balance * 0.4
        
        let loudnormEnabled = false
        
        switch genre {
        case .electronic, .hiphop:
            bassGain += 2.5
            surroundLevel = min(1.0, surroundLevel + 0.15)
        case .classical, .jazz:
            surroundLevel = max(0.1, surroundLevel - 0.1)
            reverbLevel = min(0.6, reverbLevel + 0.2)
            stereoWidth = min(1.4, stereoWidth)
        case .rock, .metal:
            trebleGain += 2.0
            surroundLevel = min(1.0, surroundLevel + 0.1)
        case .vocal, .acoustic:
            surroundLevel = max(0.1, surroundLevel - 0.15)
            reverbLevel = max(0.05, reverbLevel - 0.1)
            eqGains[5] += 1.5
            eqGains[6] += 1.0
        case .rnb:
            bassGain += 1.5
            reverbLevel = min(0.4, reverbLevel + 0.1)
        default:
            break
        }
        
        // 新增滤镜全部禁用
        return RecommendedEffects(
            bassGain: clampGain(bassGain),
            trebleGain: clampGain(trebleGain),
            surroundLevel: max(0, min(1, surroundLevel)),
            reverbLevel: max(0, min(1, reverbLevel)),
            stereoWidth: max(0.5, min(2, stereoWidth)),
            loudnormEnabled: loudnormEnabled,
            eqGains: eqGains,
            fftDenoiseEnabled: false, fftDenoiseAmount: 10,
            declickEnabled: false, declipEnabled: false,
            dynaudnormEnabled: false, speechnormEnabled: false, compandEnabled: false,
            bs2bEnabled: false, crossfeedEnabled: false, crossfeedStrength: 0.3,
            haasEnabled: false, haasDelay: 20,
            virtualbassEnabled: false, virtualbassCutoff: 250, virtualbassStrength: 3.0,
            exciterEnabled: false, exciterAmount: 3.0, exciterFreq: 7500,
            softclipEnabled: false, softclipType: 0,
            dialogueEnhanceEnabled: false
        )
    }
}
