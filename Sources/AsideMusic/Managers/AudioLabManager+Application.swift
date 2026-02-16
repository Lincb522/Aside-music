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
        
        // 应用基础音效参数
        effects.setBassGain(recommended.bassGain)
        effects.setTrebleGain(recommended.trebleGain)
        effects.setSurroundLevel(recommended.surroundLevel)
        effects.setReverbLevel(recommended.reverbLevel)
        effects.setStereoWidth(recommended.stereoWidth)
        effects.setLoudnormEnabled(recommended.loudnormEnabled)
        
        // 应用智能 EQ 曲线
        let equalizer = PlayerManager.shared.equalizer
        for (index, band) in EQBand.allCases.enumerated() {
            if index < recommended.eqGains.count {
                equalizer.setGain(recommended.eqGains[index], for: band)
            }
        }
        
        // 启用 EQ
        if !EQManager.shared.isEnabled {
            EQManager.shared.isEnabled = true
        }
        
        // 更新自定义增益
        EQManager.shared.customGains = recommended.eqGains
        
        // 设置为智能预设
        EQManager.shared.currentPreset = EQPreset(
            id: "smart_auto",
            name: "智能",
            category: .custom,
            description: "基于音频分析自动生成",
            gains: recommended.eqGains,
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
}
