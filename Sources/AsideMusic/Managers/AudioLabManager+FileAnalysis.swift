// AudioLabManager+FileAnalysis.swift
// AsideMusic
//
// 文件分析：使用 SDK AudioAnalyzer.analyzeFile 进行完整音频分析
// 增强版：多维度类型推断、深度质量评估、智能滤镜推荐

import Foundation
import FFmpegSwiftSDK

extension AudioLabManager {
    
    // MARK: - 文件分析（使用 SDK 的 AudioAnalyzer.analyzeFile）
    
    /// 从音频文件进行完整分析（增强版 — 多阶段流水线）
    func analyzeFromFile(url: String) async throws -> AudioAnalysisResult {
        AppLogger.info("开始文件分析: \(url)")
        
        let sdkResult = try await AudioAnalyzer.analyzeFile(
            url: url,
            maxDuration: 60,
            onProgress: { @Sendable [weak self] progress in
                Task { @MainActor in
                    self?.analysisProgress = 0.4 + progress * 0.45
                }
            }
        )
        
        analysisProgress = 0.9
        
        // 阶段 1：多维度类型推断
        let genre = inferGenreFromSDKResult(sdkResult)
        
        // 阶段 2：深度音色分析
        let timbre = convertTimbreAnalysis(sdkResult.timbre)
        
        // 阶段 3：增强质量评估
        let quality = convertQualityAssessment(sdkResult)
        
        analysisProgress = 0.92
        
        // 阶段 4：智能音效推荐（利用全部分析数据）
        let recommendedEffects = generateRecommendedEffectsFromSDK(
            sdkResult: sdkResult,
            genre: genre,
            timbre: timbre,
            quality: quality
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

    // MARK: - 增强类型推断（多维度加权评分）
    
    /// 从 SDK 分析结果推断音乐类型 — 使用评分矩阵而非简单 if-else
    func inferGenreFromSDKResult(_ result: AudioAnalyzer.FullAnalysisResult) -> SuggestedGenre {
        let bpm = result.bpm.bpm
        let bpmConf = result.bpm.confidence
        let freq = result.frequency
        let dynamic = result.dynamicRange
        let timbre = result.timbre
        let loudness = result.loudness
        
        // 为每种类型计算匹配分数
        var scores: [SuggestedGenre: Float] = [:]
        
        // 电子：强低频 + 高 BPM + 低动态范围（压缩感强）
        scores[.electronic] = 0
        if freq.lowEnergyRatio > 0.35 { scores[.electronic]! += (freq.lowEnergyRatio - 0.35) * 10 }
        if bpm > 115 { scores[.electronic]! += min(3, (bpm - 115) / 10) }
        if dynamic.drValue < 10 { scores[.electronic]! += Float(10 - dynamic.drValue) * 0.3 }
        if freq.midEnergyRatio < 0.35 { scores[.electronic]! += 1.5 }
        
        // 嘻哈：强低频 + 中等 BPM + 中频人声
        scores[.hiphop] = 0
        if freq.lowEnergyRatio > 0.38 { scores[.hiphop]! += (freq.lowEnergyRatio - 0.38) * 8 }
        if bpm >= 75 && bpm <= 115 { scores[.hiphop]! += 2.0 }
        if freq.midEnergyRatio > 0.3 && freq.midEnergyRatio < 0.45 { scores[.hiphop]! += 1.5 }
        
        // 摇滚：均衡偏低频 + 中高 BPM + 高动态
        scores[.rock] = 0
        if freq.lowEnergyRatio > 0.28 && freq.lowEnergyRatio < 0.45 { scores[.rock]! += 1.5 }
        if freq.midEnergyRatio > 0.3 { scores[.rock]! += 1.0 }
        if bpm > 100 && bpm < 160 { scores[.rock]! += 1.5 }
        if dynamic.drValue >= 8 { scores[.rock]! += 1.0 }
        
        // 金属：全频段高能量 + 高 BPM + 低动态（墙壁式混音）
        scores[.metal] = 0
        if freq.lowEnergyRatio > 0.3 && freq.highEnergyRatio > 0.2 { scores[.metal]! += 2.0 }
        if bpm > 130 { scores[.metal]! += min(3, (bpm - 130) / 15) }
        if dynamic.drValue < 8 { scores[.metal]! += Float(8 - dynamic.drValue) * 0.4 }
        if loudness.integratedLUFS > -10 { scores[.metal]! += 1.5 }
        
        // 流行：均衡频率 + 中等 BPM + 适中响度
        scores[.pop] = 1.0 // 基础分，作为默认选项
        if freq.lowEnergyRatio > 0.2 && freq.lowEnergyRatio < 0.4 { scores[.pop]! += 1.0 }
        if freq.midEnergyRatio > 0.3 && freq.midEnergyRatio < 0.5 { scores[.pop]! += 1.0 }
        if bpm > 90 && bpm < 135 { scores[.pop]! += 1.5 }
        
        // 人声：中频主导 + 高频谱质心 + 高清晰度
        scores[.vocal] = 0
        if freq.midEnergyRatio > 0.42 { scores[.vocal]! += (freq.midEnergyRatio - 0.42) * 10 }
        if freq.spectralCentroid > 1800 { scores[.vocal]! += 1.5 }
        if timbre.clarity > 0.6 { scores[.vocal]! += 1.5 }
        
        // 民谣：中频主导 + 温暖音色 + 慢节奏
        scores[.acoustic] = 0
        if freq.midEnergyRatio > 0.38 { scores[.acoustic]! += 1.5 }
        if timbre.warmth > 0.5 { scores[.acoustic]! += (timbre.warmth - 0.5) * 4 }
        if bpm < 120 { scores[.acoustic]! += 1.0 }
        if freq.spectralCentroid < 2200 { scores[.acoustic]! += 1.0 }
        
        // 古典：高动态范围 + 高频突出 + 低 BPM
        scores[.classical] = 0
        if dynamic.drValue >= 12 { scores[.classical]! += Float(dynamic.drValue - 12) * 0.5 + 2.0 }
        else if dynamic.drValue >= 10 { scores[.classical]! += 1.0 }
        if freq.highEnergyRatio > 0.28 { scores[.classical]! += 1.5 }
        if freq.spectralCentroid > 2500 { scores[.classical]! += 1.0 }
        if bpm < 100 && bpmConf < 0.5 { scores[.classical]! += 1.5 } // BPM 不明确常见于古典
        
        // 爵士：高频突出 + 高动态 + 中等频谱质心
        scores[.jazz] = 0
        if freq.highEnergyRatio > 0.25 { scores[.jazz]! += 1.5 }
        if dynamic.drValue >= 10 { scores[.jazz]! += 1.5 }
        if freq.spectralCentroid > 2000 && freq.spectralCentroid < 3500 { scores[.jazz]! += 1.5 }
        if bpm > 80 && bpm < 140 { scores[.jazz]! += 0.5 }
        
        // R&B：低频偏重 + 温暖 + 慢节奏
        scores[.rnb] = 0
        if freq.lowEnergyRatio > 0.32 { scores[.rnb]! += 1.5 }
        if timbre.warmth > 0.5 { scores[.rnb]! += 1.5 }
        if bpm >= 70 && bpm <= 105 { scores[.rnb]! += 2.0 }
        if freq.midEnergyRatio > 0.35 { scores[.rnb]! += 1.0 }
        
        // 选择最高分的类型
        let bestMatch = scores.max(by: { $0.value < $1.value })
        return bestMatch?.key ?? .pop
    }
    
    // MARK: - 深度音色分析
    
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
    
    // MARK: - 增强质量评估（更多维度）
    
    /// 转换 SDK 的质量评估结果（增强版 — 更多评分维度）
    func convertQualityAssessment(_ sdkResult: AudioAnalyzer.FullAnalysisResult) -> QualityInfo {
        let dynamic = sdkResult.dynamicRange
        let clipping = sdkResult.clipping
        let freq = sdkResult.frequency
        let loudness = sdkResult.loudness
        
        var issues: [String] = []
        var dynamicScore = 100
        var frequencyScore = 100
        
        // 动态范围评估（更细致的分级）
        if dynamic.drValue < 4 {
            dynamicScore -= 50
            issues.append("动态范围极窄（DR\(dynamic.drValue)），严重过度压缩")
        } else if dynamic.drValue < 6 {
            dynamicScore -= 40
            issues.append("动态范围过窄（DR\(dynamic.drValue)）")
        } else if dynamic.drValue < 8 {
            dynamicScore -= 25
            issues.append("动态范围偏窄（DR\(dynamic.drValue)）")
        } else if dynamic.drValue < 10 {
            dynamicScore -= 10
        }
        
        // 削波检测
        if clipping.hasSevereClipping {
            dynamicScore -= 30
            issues.append("存在严重削波")
        } else if clipping.clippingPercentage > 0.001 {
            dynamicScore -= 15
            issues.append("存在轻微削波")
        }
        
        // 响度评估
        if loudness.integratedLUFS > -8 {
            dynamicScore -= 20
            issues.append("响度过高（\(String(format: "%.1f", loudness.integratedLUFS)) LUFS），可能存在过度限制")
        } else if loudness.integratedLUFS < -20 {
            dynamicScore -= 10
            issues.append("响度偏低（\(String(format: "%.1f", loudness.integratedLUFS)) LUFS）")
        }
        
        // 频率平衡评估
        if freq.lowEnergyRatio > 0.55 {
            frequencyScore -= 25
            issues.append("低频严重过重")
        } else if freq.lowEnergyRatio > 0.45 {
            frequencyScore -= 15
            issues.append("低频偏重")
        } else if freq.lowEnergyRatio < 0.1 {
            frequencyScore -= 20
            issues.append("低频严重不足")
        } else if freq.lowEnergyRatio < 0.15 {
            frequencyScore -= 10
            issues.append("低频偏弱")
        }
        
        if freq.highEnergyRatio > 0.45 {
            frequencyScore -= 20
            issues.append("高频过亮，可能刺耳")
        } else if freq.highEnergyRatio > 0.38 {
            frequencyScore -= 10
            issues.append("高频偏亮")
        }
        
        if freq.midEnergyRatio < 0.2 {
            frequencyScore -= 15
            issues.append("中频凹陷，人声可能不够突出")
        }
        
        // 频谱质心异常检测
        if freq.spectralCentroid > 5000 {
            frequencyScore -= 10
            issues.append("频谱质心偏高，整体偏亮")
        } else if freq.spectralCentroid < 800 {
            frequencyScore -= 10
            issues.append("频谱质心偏低，整体偏暗")
        }
        
        // 立体声宽度评估
        if let phase = sdkResult.phase {
            if phase.stereoWidth < 0.15 {
                frequencyScore -= 10
                issues.append("立体声宽度极窄，接近单声道")
            } else if phase.correlation < -0.3 {
                frequencyScore -= 10
                issues.append("立体声相位异常，可能存在反相问题")
            }
        }
        
        let overallScore = max(0, (dynamicScore + frequencyScore) / 2)
        let grade: String
        if overallScore >= 90 { grade = "优秀" }
        else if overallScore >= 80 { grade = "良好" }
        else if overallScore >= 65 { grade = "一般" }
        else if overallScore >= 50 { grade = "较差" }
        else { grade = "很差" }
        
        if issues.isEmpty {
            issues.append("音频质量良好，无明显问题")
        }
        
        return QualityInfo(
            overallScore: overallScore,
            dynamicScore: dynamicScore,
            frequencyScore: frequencyScore,
            grade: grade,
            issues: issues
        )
    }

    // MARK: - 增强音效推荐（利用全部分析数据 + 智能滤镜）
    
    /// 基于 SDK 完整分析结果生成推荐音效参数（增强版 — 智能滤镜推荐）
    func generateRecommendedEffectsFromSDK(
        sdkResult: AudioAnalyzer.FullAnalysisResult,
        genre: SuggestedGenre,
        timbre: TimbreInfo? = nil,
        quality: QualityInfo? = nil
    ) -> RecommendedEffects {
        let freq = sdkResult.frequency
        let dynamic = sdkResult.dynamicRange
        let _ = sdkResult.loudness
        
        // ═══════════════════════════════════════
        // 智能 EQ 生成算法（基于完整频率分析）
        // ═══════════════════════════════════════
        
        var eqGains: [Float] = Array(repeating: 0, count: 10)
        
        // 根据类型调整理想频率分布目标
        let idealLow: Float
        let idealMid: Float
        let idealHigh: Float
        
        switch genre {
        case .electronic, .hiphop:
            idealLow = 0.35; idealMid = 0.38; idealHigh = 0.27
        case .classical, .jazz:
            idealLow = 0.25; idealMid = 0.40; idealHigh = 0.35
        case .rock, .metal:
            idealLow = 0.32; idealMid = 0.38; idealHigh = 0.30
        case .vocal, .acoustic:
            idealLow = 0.25; idealMid = 0.48; idealHigh = 0.27
        case .rnb:
            idealLow = 0.35; idealMid = 0.40; idealHigh = 0.25
        default:
            idealLow = 0.30; idealMid = 0.40; idealHigh = 0.30
        }
        
        let lowDiff = idealLow - freq.lowEnergyRatio
        let midDiff = idealMid - freq.midEnergyRatio
        let highDiff = idealHigh - freq.highEnergyRatio
        
        // 低频段 EQ（31Hz ~ 250Hz）
        let lowBoost = lowDiff * 18
        eqGains[0] = clampGain(lowBoost * 0.7)   // 31Hz
        eqGains[1] = clampGain(lowBoost * 1.0)   // 62Hz
        eqGains[2] = clampGain(lowBoost * 0.85)  // 125Hz
        eqGains[3] = clampGain(lowBoost * 0.3 + midDiff * 0.4) // 250Hz 过渡
        
        // 中频段 EQ（500Hz ~ 2kHz）
        let midBoost = midDiff * 14
        eqGains[4] = clampGain(midBoost * 0.6)   // 500Hz
        eqGains[5] = clampGain(midBoost * 1.0)   // 1kHz
        eqGains[6] = clampGain(midBoost * 0.85)  // 2kHz
        
        // 高频段 EQ（4kHz ~ 16kHz）
        let highBoost = highDiff * 18
        eqGains[7] = clampGain(highBoost * 0.6 + midBoost * 0.2) // 4kHz 过渡
        eqGains[8] = clampGain(highBoost * 1.0)  // 8kHz
        eqGains[9] = clampGain(highBoost * 0.75) // 16kHz
        
        // 频谱质心校正
        let centroidTarget: Float = 2200
        let brightnessAdjust = clampGain((centroidTarget - freq.spectralCentroid) / 400)
        eqGains[7] += brightnessAdjust * 0.25
        eqGains[8] += brightnessAdjust * 0.4
        eqGains[9] += brightnessAdjust * 0.3
        
        // 音色补偿：如果音色偏暗，额外提升高频
        if let t = timbre, t.brightness < 0.3 {
            let brightBoost = (0.3 - t.brightness) * 4
            eqGains[8] += clampGain(brightBoost)
            eqGains[9] += clampGain(brightBoost * 0.7)
        }
        // 如果音色偏薄，补充中低频
        if let t = timbre, t.fullness < 0.3 {
            let fullBoost = (0.3 - t.fullness) * 3
            eqGains[3] += clampGain(fullBoost)
            eqGains[4] += clampGain(fullBoost * 0.8)
        }
        
        for i in 0..<10 {
            eqGains[i] = clampGain(eqGains[i])
        }

        // ═══════════════════════════════════════
        // 智能音效参数生成
        // ═══════════════════════════════════════
        
        var bassGain: Float = lowDiff * 10
        var trebleGain: Float = highDiff * 10
        
        var surroundLevel: Float = 0.2 + freq.lowEnergyRatio * 0.3
        if let phase = sdkResult.phase {
            if phase.stereoWidth < 0.3 {
                surroundLevel += 0.2 // 窄立体声需要更多环绕
            } else if phase.stereoWidth > 0.8 {
                surroundLevel = max(0.1, surroundLevel - 0.1) // 已经很宽，减少环绕
            }
        }
        
        var reverbLevel: Float = 0.1 + freq.highEnergyRatio * 0.25
        if dynamic.drValue >= 12 {
            reverbLevel += 0.15 // 高动态范围适合更多混响
        }
        
        let balance = 1.0 - abs(freq.lowEnergyRatio - freq.highEnergyRatio)
        var stereoWidth: Float = 1.0 + balance * 0.4
        
        let loudnormEnabled = false
        
        // 类型特化调整
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
            eqGains[5] += 1.5 // 人声频段增强
            eqGains[6] += 1.0
        case .rnb:
            bassGain += 1.5
            reverbLevel = min(0.4, reverbLevel + 0.1)
        default:
            break
        }
        
        // ═══════════════════════════════════════
        // 智能滤镜推荐（仅计算推荐参数，不自动启用）
        // 注意：这些滤镜之前因兼容性问题会导致无声，全部保持禁用
        // 参数仅作为分析结果供 UI 展示，用户可手动开启
        // ═══════════════════════════════════════
        
        let fftDenoiseEnabled = false
        let fftDenoiseAmount: Float = 10
        let declickEnabled = false
        let declipEnabled = false
        let virtualbassEnabled = false
        let virtualbassCutoff: Float = 250
        var virtualbassStrength: Float = 3.0
        let exciterEnabled = false
        var exciterAmount: Float = 3.0
        let exciterFreq: Float = 7500
        let bs2bEnabled = false
        let crossfeedEnabled = false
        var crossfeedStrength: Float = 0.3
        let dialogueEnhanceEnabled = false
        
        // 仅计算推荐参数值（不启用滤镜）
        if quality != nil {
            // 削波：记录推荐参数但不启用
            // declip 保持 false
            
            // 低频不足时计算虚拟低音推荐强度
            if freq.lowEnergyRatio < 0.15 {
                virtualbassStrength = min(5.0, (0.15 - freq.lowEnergyRatio) * 30 + 2.0)
            }
            
            // 高频暗淡时计算激励器推荐量
            if let t = timbre, t.brightness < 0.25 {
                exciterAmount = min(5.0, (0.25 - t.brightness) * 15 + 2.0)
            }
        }
        
        // 立体声宽度极窄时计算 crossfeed 推荐强度
        if let phase = sdkResult.phase, phase.stereoWidth < 0.2 {
            crossfeedStrength = 0.4
        }
        
        let stabilizedEQ = stabilizeSmartEQCurve(
            eqGains,
            genre: genre,
            confidence: sdkResult.bpm.confidence,
            quality: quality,
            timbre: timbre,
            loudness: sdkResult.loudness.integratedLUFS,
            dynamicRange: Float(dynamic.drValue)
        )
        
        let safetyFactor = smartEffectSafetyFactor(
            quality: quality,
            dynamicRange: Float(dynamic.drValue),
            loudness: sdkResult.loudness.integratedLUFS
        )
        let tonalSafety = 0.82 + safetyFactor * 0.18
        let spatialSafety = 0.7 + safetyFactor * 0.3
        
        return RecommendedEffects(
            bassGain: clampGain(bassGain * tonalSafety),
            trebleGain: clampGain(trebleGain * tonalSafety),
            surroundLevel: clampValue(surroundLevel * spatialSafety, min: 0, max: 1),
            reverbLevel: clampValue(reverbLevel * spatialSafety, min: 0, max: 1),
            stereoWidth: clampValue(1.0 + (stereoWidth - 1.0) * spatialSafety, min: 0.5, max: 2),
            loudnormEnabled: loudnormEnabled,
            eqGains: stabilizedEQ,
            fftDenoiseEnabled: fftDenoiseEnabled, fftDenoiseAmount: fftDenoiseAmount,
            declickEnabled: declickEnabled, declipEnabled: declipEnabled,
            dynaudnormEnabled: false, speechnormEnabled: false, compandEnabled: false,
            bs2bEnabled: bs2bEnabled, crossfeedEnabled: crossfeedEnabled, crossfeedStrength: crossfeedStrength,
            haasEnabled: false, haasDelay: 20,
            virtualbassEnabled: virtualbassEnabled, virtualbassCutoff: virtualbassCutoff, virtualbassStrength: virtualbassStrength,
            exciterEnabled: exciterEnabled, exciterAmount: exciterAmount, exciterFreq: exciterFreq,
            softclipEnabled: false, softclipType: 0,
            dialogueEnhanceEnabled: dialogueEnhanceEnabled
        )
    }
}
