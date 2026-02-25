// EQManager.swift
// AsideMusic
//
// 均衡器管理器：预设管理、状态持久化、实时应用
// 所有预设参数基于专业音频工程标准

import Foundation
import Combine
import FFmpegSwiftSDK

@MainActor
class EQManager: ObservableObject {
    static let shared = EQManager()
    
    /// 恢复状态时跳过 didSet 副作用
    private var isRestoring = false
    
    /// 当前前级补偿值 (dB)，由安全系统自动管理
    @Published private(set) var preampDB: Float = 0
    
    // MARK: - Published
    
    @Published var isEnabled: Bool = false {
        didSet {
            guard !isRestoring else { return }
            if !isEnabled {
                PlayerManager.shared.equalizer.reset()
                PlayerManager.shared.audioEffects.setBassGain(0)
                PlayerManager.shared.audioEffects.setTrebleGain(0)
                PlayerManager.shared.audioEffects.setSurroundLevel(0)
                PlayerManager.shared.audioEffects.setReverbLevel(0)
                PlayerManager.shared.setPitch(0)
                disableSafetyMeasures()
                saveAudioEffectsState()
            } else {
                if let preset = currentPreset {
                    preset.apply(to: PlayerManager.shared.equalizer)
                }
                updateSafetyLimiter()
            }
            saveState()
        }
    }
    
    @Published var currentPreset: EQPreset? = nil {
        didSet {
            guard !isRestoring else { return }
            if isEnabled, let preset = currentPreset {
                preset.apply(to: PlayerManager.shared.equalizer)
            }
            saveState()
        }
    }
    
    @Published var customGains: [Float] = Array(repeating: 0, count: 10) {
        didSet {
            guard !isRestoring else { return }
            if isEnabled && currentPreset?.id == "custom" {
                applyCustomGains()
            }
        }
    }
    
    @Published var customPresets: [EQPreset] = []
    
    // MARK: - 内置预设
    //
    // 预设参数说明：
    // 10 段频率: 31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
    // 增益范围: -12dB ~ +12dB
    //
    // 参数设计依据：
    // - 低频 (31-125Hz): 控制低音体感和温暖度
    // - 中低频 (250-500Hz): 控制浑浊感和饱满度，过多会闷
    // - 中频 (1-2kHz): 人声基频和乐器主体
    // - 中高频 (4kHz): 临场感和齿音区域
    // - 高频 (8-16kHz): 空气感和亮度
    
    let builtInPresets: [EQPreset] = EQManager.loadBuiltInPresets()
    
    /// 从 Bundle 中的 eq_presets.json 加载内置预设
    private static func loadBuiltInPresets() -> [EQPreset] {
        // 多路径查找
        guard let url = Bundle.main.url(forResource: "eq_presets", withExtension: "json")
                ?? Bundle.main.url(forResource: "eq_presets", withExtension: "json", subdirectory: "Resources") else {
            AppLogger.warning("[EQManager] Bundle 中未找到 eq_presets.json")
            return embeddedFallbackPresets
        }
        
        AppLogger.debug("[EQManager] 找到文件路径: \(url.path)")
        
        // 用 FileManager 检查文件是否真实存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            AppLogger.warning("[EQManager] 文件路径存在但文件不存在: \(url.path)")
            return embeddedFallbackPresets
        }
        
        guard let data = FileManager.default.contents(atPath: url.path), !data.isEmpty else {
            AppLogger.warning("[EQManager] 文件为空或无法读取: \(url.path)")
            return embeddedFallbackPresets
        }
        
        do {
            let presets = try JSONDecoder().decode([EQPreset].self, from: data)
            AppLogger.debug("[EQManager] 从 JSON 加载了 \(presets.count) 个内置预设")
            return presets
        } catch {
            AppLogger.warning("[EQManager] JSON 解码失败: \(error)")
            return embeddedFallbackPresets
        }
    }
    
    /// 内嵌兜底预设（当 JSON 文件无法加载时使用）
    private static let embeddedFallbackPresets: [EQPreset] = [
        EQPreset(id: "flat", name: "平坦", category: .flat, description: "无修饰的原始音频", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        EQPreset(id: "pop", name: "流行", category: .genre, description: "增强低频和高频", gains: [1.0, 1.5, 1.2, 0.3, -1.0, -1.2, 0.5, 1.5, 2.0, 1.2]),
        EQPreset(id: "rock", name: "摇滚", category: .genre, description: "强劲的中低频和明亮的高频", gains: [2.0, 2.5, 1.5, 0.3, -1.2, 0.0, 1.2, 2.0, 1.5, 0.5]),
        EQPreset(id: "vocal_enhance", name: "人声增强", category: .vocal, description: "突出人声清晰度", gains: [-2.0, -1.5, -0.8, -0.3, 0.5, 2.0, 3.0, 2.2, 1.0, 0.5]),
        EQPreset(id: "bass_boost", name: "低音增强", category: .scene, description: "增强低频冲击力", gains: [4.0, 3.5, 2.2, 1.0, 0.0, -0.3, 0.0, 0.0, 0.0, 0.0]),
    ]
    
    // MARK: - Init
    
    private init() {
        isRestoring = true
        restoreState()
        isRestoring = false
    }
    
    // MARK: - 所有预设（内置 + 自定义）
    
    var allPresets: [EQPreset] {
        builtInPresets + customPresets
    }
    
    func presets(for category: EQPresetCategory) -> [EQPreset] {
        if category == .custom {
            return customPresets
        }
        return builtInPresets.filter { $0.category == category }
    }
    
    // MARK: - 应用预设
    
    func applyPreset(_ preset: EQPreset) {
        // 环绕类切到非环绕类时，自动归零空间参数
        if let oldPreset = currentPreset,
           oldPreset.category == .surround && preset.category != .surround {
            let effects = PlayerManager.shared.audioEffects
            effects.setSurroundLevel(0)
            effects.setReverbLevel(0)
            effects.setStereoWidth(1.0)
        }
        
        currentPreset = preset
        if !isEnabled {
            isEnabled = true
        }
        if preset.category == .surround {
            preset.applySurroundEffects(to: PlayerManager.shared.audioEffects)
        }
        updateSafetyLimiter()
        saveAudioEffectsState()
    }
    
    func applyFlat() {
        currentPreset = builtInPresets.first { $0.id == "flat" }
        PlayerManager.shared.equalizer.reset()
        updateSafetyLimiter()
    }
    
    // MARK: - 自定义增益
    
    func setCustomGain(_ gain: Float, at index: Int) {
        guard index >= 0 && index < 10 else { return }
        customGains[index] = EQBandGain.clamped(gain)
        if isEnabled {
            let band = EQBand.allCases[index]
            PlayerManager.shared.equalizer.setGain(customGains[index], for: band)
            updateSafetyLimiter()
        }
    }
    
    private func applyCustomGains() {
        for (index, band) in EQBand.allCases.enumerated() {
            if index < customGains.count {
                PlayerManager.shared.equalizer.setGain(customGains[index], for: band)
            }
        }
        updateSafetyLimiter()
    }
    
    // MARK: - 安全增益管理（前级补偿 + 限幅器）
    
    /// 根据当前 EQ 增益峰值和旋钮状态，自动调整前级补偿并启用安全限幅器
    func updateSafetyLimiter() {
        let effects = PlayerManager.shared.audioEffects
        guard isEnabled else {
            disableSafetyMeasures()
            return
        }
        
        let gains: [Float]
        if let preset = currentPreset, preset.id != "custom" {
            gains = preset.gains
        } else {
            gains = customGains
        }
        
        let maxEQGain = gains.max() ?? 0
        let bassKnob = max(effects.bassGain, 0)
        let trebleKnob = max(effects.trebleGain, 0)
        let peakGain = max(maxEQGain, max(bassKnob, trebleKnob))
        
        // 前级补偿：峰值正增益超过 1.5 dB 时按比例衰减，防止输出削波
        let newPreamp: Float
        if peakGain > 1.5 {
            newPreamp = -(peakGain - 1.5) * 0.65
        } else {
            newPreamp = 0
        }
        
        if abs(newPreamp - preampDB) > 0.05 {
            preampDB = newPreamp
            effects.setVolume(newPreamp)
        }
        
        // 安全限幅器：任何正增益超过 0.5 dB 即启用，阈值 -0.5 dBFS
        if peakGain > 0.5 {
            effects.setLimiterEnabled(true)
            effects.setLimiterLimit(-0.5)
        } else {
            effects.setLimiterEnabled(false)
        }
    }
    
    private func disableSafetyMeasures() {
        let effects = PlayerManager.shared.audioEffects
        if preampDB != 0 {
            preampDB = 0
            effects.setVolume(0)
        }
        effects.setLimiterEnabled(false)
    }
    
    // MARK: - 自定义预设管理
    
    func saveCustomPreset(name: String, description: String = "") {
        let preset = EQPreset(
            id: "custom_\(UUID().uuidString.prefix(8))",
            name: name,
            category: .custom,
            description: description,
            gains: customGains,
            isCustom: true
        )
        customPresets.append(preset)
        saveState()
    }
    
    func deleteCustomPreset(_ preset: EQPreset) {
        customPresets.removeAll { $0.id == preset.id }
        if currentPreset?.id == preset.id {
            applyFlat()
        }
        saveState()
    }
    
    // MARK: - 持久化
    
    private struct EQState: Codable {
        let isEnabled: Bool
        let currentPresetId: String?
        let customGains: [Float]
        let customPresets: [EQPreset]
    }
    
    /// 音效旋钮状态（独立于 EQ）
    private struct AudioEffectsState: Codable {
        let bassGain: Float
        let trebleGain: Float
        let surroundLevel: Float
        let reverbLevel: Float
    }
    
    private func saveState() {
        let state = EQState(
            isEnabled: isEnabled,
            currentPresetId: currentPreset?.id,
            customGains: customGains,
            customPresets: customPresets
        )
        OptimizedCacheManager.shared.setObject(state, forKey: "eq_state_v4")
    }
    
    /// 保存音效旋钮状态（低音/高音/环绕/混响，独立于 EQ）
    func saveAudioEffectsState() {
        let effects = PlayerManager.shared.audioEffects
        let state = AudioEffectsState(
            bassGain: effects.bassGain,
            trebleGain: effects.trebleGain,
            surroundLevel: effects.surroundLevel,
            reverbLevel: effects.reverbLevel
        )
        OptimizedCacheManager.shared.setObject(state, forKey: "audio_effects_state")
    }
    
    private func restoreAudioEffectsState() {
        guard let state = OptimizedCacheManager.shared.getObject(forKey: "audio_effects_state", type: AudioEffectsState.self) else { return }
        let effects = PlayerManager.shared.audioEffects
        if state.bassGain != 0 { effects.setBassGain(state.bassGain) }
        if state.trebleGain != 0 { effects.setTrebleGain(state.trebleGain) }
        if state.surroundLevel > 0 { effects.setSurroundLevel(state.surroundLevel) }
        if state.reverbLevel > 0 { effects.setReverbLevel(state.reverbLevel) }
    }
    
    private func restoreState() {
        // 恢复音效旋钮（独立于 EQ，始终恢复）
        restoreAudioEffectsState()
        
        // v4（移除 18 段后的新格式）
        if let state = OptimizedCacheManager.shared.getObject(forKey: "eq_state_v4", type: EQState.self) {
            self.customPresets = state.customPresets
            self.customGains = state.customGains
            self.isEnabled = state.isEnabled
            if let presetId = state.currentPresetId {
                self.currentPreset = allPresets.first { $0.id == presetId }
            }
            if isEnabled, let preset = currentPreset {
                preset.apply(to: PlayerManager.shared.equalizer)
            }
            updateSafetyLimiter()
            return
        }
        // 兼容旧版本（v1/v2/v3），只恢复 10 段数据
        struct LegacyEQState: Codable {
            let isEnabled: Bool
            let currentPresetId: String?
            let customGains: [Float]
            let customPresets: [EQPreset]
            let eqMode: String?
            let superEQGains: [Float]?
            let currentSuperEQPresetId: String?
        }
        for key in ["eq_state_v3", "eq_state_v2", "eq_state_v1"] {
            if let state = OptimizedCacheManager.shared.getObject(forKey: key, type: LegacyEQState.self) {
                self.customPresets = state.customPresets.filter { $0.presetType == .standard10 }
                self.customGains = state.customGains
                self.isEnabled = state.isEnabled
                if let presetId = state.currentPresetId {
                    self.currentPreset = allPresets.first { $0.id == presetId }
                }
                if isEnabled, let preset = currentPreset {
                    preset.apply(to: PlayerManager.shared.equalizer)
                }
                updateSafetyLimiter()
                // 迁移到 v4
                saveState()
                return
            }
        }
    }
}
