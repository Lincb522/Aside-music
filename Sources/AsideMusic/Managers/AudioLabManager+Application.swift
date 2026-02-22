// AudioLabManager+Application.swift
// AsideMusic
//
// 应用推荐设置、重置、EQ 预设映射、持久化

import Foundation
import FFmpegSwiftSDK
extension AudioLabManager {
    
    // MARK: - 应用推荐设置
    
    /// 应用推荐的音效设置
    func applyRecommendedSettings(_ analysis: AudioAnalysisResult) {
        let effects = PlayerManager.shared.audioEffects
        let recommended = analysis.recommendedEffects
        let appliedEQ = recommended.eqGains.count == 10
            ? recommended.eqGains
            : Array((recommended.eqGains + Array(repeating: 0, count: 10)).prefix(10))
        
        // 应用基础音效参数（使用分析阶段已优化过的推荐值）
        effects.setBassGain(clampGain(recommended.bassGain))
        effects.setTrebleGain(clampGain(recommended.trebleGain))
        effects.setSurroundLevel(clampValue(recommended.surroundLevel, min: 0, max: 1))
        effects.setReverbLevel(clampValue(recommended.reverbLevel, min: 0, max: 1))
        effects.setStereoWidth(clampValue(recommended.stereoWidth, min: 0.5, max: 2.0))
        effects.setLoudnormEnabled(recommended.loudnormEnabled)
        
        // 应用智能 EQ 曲线
        let equalizer = PlayerManager.shared.equalizer
        for (index, band) in EQBand.allCases.enumerated() {
            if index < appliedEQ.count {
                equalizer.setGain(appliedEQ[index], for: band)
            }
        }
        
        // 启用 EQ
        if !EQManager.shared.isEnabled {
            EQManager.shared.isEnabled = true
        }
        
        // 更新自定义增益
        EQManager.shared.customGains = appliedEQ
        
        // 设置为智能预设
        EQManager.shared.currentPreset = EQPreset(
            id: "smart_auto",
            name: "智能",
            category: .custom,
            description: "基于音频分析自动生成",
            gains: appliedEQ,
            isCustom: true
        )
        
        EQManager.shared.saveAudioEffectsState()
        
        let modeText = analysisMode == .file ? "文件分析" : "实时分析"
        AppLogger.info("智能音效已应用（\(modeText)）: \(analysis.suggestedGenre.rawValue) 风格")
    }
    
    /// 手动应用当前分析结果
    func applyCurrentAnalysis() {
        guard let analysis = currentAnalysis else { return }
        applyRecommendedSettings(analysis)
    }
    
    /// 重置为手动模式（关闭智能分析时调用）
    func resetToManualMode() {
        currentAnalysis = nil
        lastAnalyzedSongId = nil
        resetEQToDefault()
    }
    
    /// 重置 EQ 和音效参数到默认值
    func resetEQToDefault() {
        let effects = PlayerManager.shared.audioEffects
        effects.setBassGain(0)
        effects.setTrebleGain(0)
        effects.setSurroundLevel(0)
        effects.setReverbLevel(0)
        effects.setStereoWidth(1.0)
        effects.setLoudnormEnabled(false)
        
        EQManager.shared.applyFlat()
        EQManager.shared.saveAudioEffectsState()
        
        AppLogger.info("智能音效已关闭，EQ 和所有滤镜已重置为默认值")
    }
    
    /// 获取推荐的 EQ 预设
    func getRecommendedPreset(for genre: SuggestedGenre) -> String {
        switch genre {
        case .pop: return "pop"
        case .rock: return "rock"
        case .electronic: return "electronic"
        case .hiphop: return "hiphop"
        case .classical: return "classical"
        case .jazz: return "jazz"
        case .rnb: return "rnb"
        case .acoustic: return "acoustic"
        case .vocal: return "vocal_enhance"
        case .metal: return "metal"
        case .unknown: return "flat"
        }
    }
    
    /// 限制增益范围
    func clampGain(_ gain: Float) -> Float {
        return max(-12, min(12, gain))
    }
    
    /// 对智能 EQ 曲线进行后处理：置信度缩放、参考曲线融合、平滑与安全限制
    func stabilizeSmartEQCurve(
        _ gains: [Float],
        genre: SuggestedGenre,
        confidence: Float,
        quality: QualityInfo?,
        timbre: TimbreInfo?,
        loudness: Float?,
        dynamicRange: Float?
    ) -> [Float] {
        var curve = gains
        if curve.count < 10 {
            curve += Array(repeating: 0, count: 10 - curve.count)
        } else if curve.count > 10 {
            curve = Array(curve.prefix(10))
        }
        
        let boundedConfidence = clampValue(confidence, min: 0.35, max: 0.98)
        let qualityFactor: Float = {
            guard let quality else { return 0.85 }
            return clampValue(Float(quality.overallScore) / 100, min: 0.55, max: 1.0)
        }()
        let dynamicFactor: Float = {
            guard let dr = dynamicRange else { return 0.9 }
            if dr < 6 { return 0.65 }
            if dr < 8 { return 0.8 }
            return 1.0
        }()
        let loudnessFactor: Float = {
            guard let lufs = loudness else { return 0.95 }
            if lufs > -9.0 { return 0.78 }
            if lufs > -11.0 { return 0.88 }
            return 1.0
        }()
        
        let strength = clampValue(
            (0.52 + boundedConfidence * 0.26 + qualityFactor * 0.22) * dynamicFactor * loudnessFactor,
            min: 0.42,
            max: 1.0
        )
        
        for i in 0..<curve.count {
            curve[i] *= strength
        }
        
        let reference = smartGenreReferenceCurve(for: genre)
        let referenceBlend = clampValue(0.14 + (1.0 - boundedConfidence) * 0.20, min: 0.14, max: 0.34)
        for i in 0..<curve.count {
            curve[i] = curve[i] * (1 - referenceBlend) + reference[i] * referenceBlend
        }
        
        if let timbre {
            if timbre.brightness > 0.78 {
                let cut = min(1.8, (timbre.brightness - 0.78) * 8.0)
                curve[8] -= cut
                curve[9] -= cut * 0.7
            } else if timbre.brightness < 0.24 {
                let lift = min(1.6, (0.24 - timbre.brightness) * 7.0)
                curve[8] += lift
                curve[9] += lift * 0.6
            }
            if timbre.warmth < 0.22 {
                let lift = min(1.5, (0.22 - timbre.warmth) * 7.0)
                curve[2] += lift
                curve[3] += lift * 0.8
            }
        }
        
        var smoothed = curve
        for i in 0..<curve.count {
            var total = curve[i] * 0.6
            var weight: Float = 0.6
            if i > 0 {
                total += curve[i - 1] * 0.2
                weight += 0.2
            }
            if i < curve.count - 1 {
                total += curve[i + 1] * 0.2
                weight += 0.2
            }
            smoothed[i] = total / weight
        }
        
        let slopeLimit: Float = 2.8
        for i in 1..<smoothed.count {
            let diff = smoothed[i] - smoothed[i - 1]
            if diff > slopeLimit {
                smoothed[i] = smoothed[i - 1] + slopeLimit
            } else if diff < -slopeLimit {
                smoothed[i] = smoothed[i - 1] - slopeLimit
            }
        }
        
        let maxPositive = smoothed.max() ?? 0
        if maxPositive > 6.5 {
            let scale = 6.5 / maxPositive
            for i in 0..<smoothed.count where smoothed[i] > 0 {
                smoothed[i] *= scale
            }
        }
        
        let hardLimit: Float = (quality?.overallScore ?? 100) < 60 ? 6.0 : 8.0
        for i in 0..<smoothed.count {
            smoothed[i] = clampValue(smoothed[i], min: -hardLimit, max: hardLimit)
        }
        
        return smoothed
    }
    
    /// 根据分析质量给环绕/混响/声场计算安全系数，避免过处理
    func smartEffectSafetyFactor(quality: QualityInfo?, dynamicRange: Float, loudness: Float?) -> Float {
        var factor: Float = 1.0
        
        if dynamicRange < 6 {
            factor *= 0.72
        } else if dynamicRange < 8 {
            factor *= 0.85
        }
        
        if let loudness, loudness > -9 {
            factor *= 0.78
        }
        
        if let quality {
            if quality.overallScore < 55 {
                factor *= 0.65
            } else if quality.overallScore < 70 {
                factor *= 0.82
            }
        }
        
        return clampValue(factor, min: 0.55, max: 1.0)
    }
    
    /// 风格参考曲线（用于在低置信度时稳定推荐）
    func smartGenreReferenceCurve(for genre: SuggestedGenre) -> [Float] {
        switch genre {
        case .electronic:
            return [1.2, 2.0, 1.6, 0.4, -0.4, -0.2, 0.2, 0.8, 1.1, 0.8]
        case .hiphop:
            return [1.6, 2.4, 1.8, 0.8, -0.2, -0.3, 0.0, 0.5, 0.7, 0.4]
        case .rock:
            return [1.0, 1.4, 1.0, 0.2, -0.2, 0.4, 1.0, 1.4, 1.2, 0.6]
        case .metal:
            return [1.2, 1.8, 1.2, 0.0, -0.4, 0.5, 1.4, 1.8, 1.4, 0.8]
        case .classical:
            return [-0.8, -0.4, 0.0, 0.4, 0.8, 0.8, 0.6, 0.9, 1.0, 0.8]
        case .jazz:
            return [-0.4, 0.0, 0.3, 0.6, 0.8, 0.7, 0.5, 0.9, 1.0, 0.8]
        case .rnb:
            return [1.2, 1.8, 1.4, 0.6, 0.2, 0.2, 0.4, 0.9, 1.0, 0.6]
        case .acoustic:
            return [-0.6, -0.2, 0.2, 0.5, 0.8, 0.9, 0.6, 0.2, -0.1, -0.3]
        case .vocal:
            return [-1.2, -0.8, -0.3, 0.1, 0.7, 1.6, 1.8, 1.0, 0.5, 0.2]
        case .pop:
            return [0.6, 1.0, 0.8, 0.2, 0.0, 0.2, 0.4, 0.8, 1.0, 0.7]
        case .unknown:
            return Array(repeating: 0, count: 10)
        }
    }
    
    func clampValue(_ value: Float, min minValue: Float, max maxValue: Float) -> Float {
        if value < minValue { return minValue }
        if value > maxValue { return maxValue }
        return value
    }
}
