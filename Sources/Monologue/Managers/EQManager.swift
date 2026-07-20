// EQManager.swift
// Monologue
//
// 均衡器管理器：预设管理、状态持久化、实时应用
// 所有预设参数基于专业音频工程标准

import Foundation
import Combine
import AVFoundation
import FFmpegSwiftSDK

enum MonoAudioOutputKind: String, Codable, CaseIterable, Identifiable {
    case builtInSpeaker
    case wired
    case bluetooth
    case car
    case airPlay
    case usb
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .builtInSpeaker: return String(localized: "eq_output_speaker")
        case .wired: return String(localized: "eq_output_wired")
        case .bluetooth: return String(localized: "eq_output_bluetooth")
        case .car: return String(localized: "eq_output_car")
        case .airPlay: return "AirPlay"
        case .usb: return String(localized: "eq_output_usb")
        case .other: return String(localized: "eq_output_other")
        }
    }

    var defaultCalibration: [Float] {
        switch self {
        case .builtInSpeaker:
            return [-2.8, -1.8, 0.4, 0.8, 0.35, 0, 0.25, 0.2, -0.3, -0.8]
        case .car:
            return [-0.4, 0.25, 0.55, 0.2, -0.45, -0.2, 0.25, 0.3, 0, -0.35]
        case .bluetooth:
            return [-0.2, 0.1, 0.15, 0, -0.1, 0, 0.1, 0.1, 0, -0.15]
        case .wired, .airPlay, .usb, .other:
            return Array(repeating: 0, count: 10)
        }
    }
}

struct MonoHeadphoneCorrectionProfile: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var matchedDeviceName: String
    var matchedDeviceUID: String
    var gains: [Float]
    var isCustom: Bool

    init(id: String, name: String, matchedDeviceName: String = "", matchedDeviceUID: String = "", gains: [Float], isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.matchedDeviceName = matchedDeviceName
        self.matchedDeviceUID = matchedDeviceUID
        self.gains = Array(gains.prefix(10)) + Array(repeating: 0, count: max(0, 10 - gains.count))
        self.isCustom = isCustom
    }
}

@MainActor
class EQManager: ObservableObject {
    static let shared = EQManager()
    
    /// 恢复状态时跳过 didSet 副作用
    private var isRestoring = false
    
    /// 当前前级补偿值 (dB)，由安全系统自动管理
    @Published private(set) var preampDB: Float = 0
    @Published private(set) var currentOutputKind: MonoAudioOutputKind = .other
    @Published private(set) var currentOutputName: String = ""
    @Published private(set) var adaptiveGains: [Float] = Array(repeating: 0, count: 10)
    @Published private(set) var isAuditioningReference = false

    /// 专业处理总强度。1.0 保留原始参数，默认略加强以便在移动设备上保持可感知。
    @Published var professionalProcessingIntensity: Float = 1.3 {
        didSet {
            // Restore/AI apply may write persisted values. Do not clamp by assigning
            // back from didSet while restoring; that can recursively re-enter the
            // @Published setter when the stored value is malformed.
            guard !isRestoring else { return }
            let clamped = Self.clampedProfessionalIntensity(professionalProcessingIntensity)
            if abs(clamped - professionalProcessingIntensity) > 0.001 {
                professionalProcessingIntensity = clamped
                return
            }
            applyProfessionalConfiguration()
            saveProfessionalState()
        }
    }

    @Published var isLoudnessMatchingEnabled = true {
        didSet { headroomSettingChanged() }
    }
    @Published var isOutputCalibrationEnabled = true {
        didSet { calibrationSettingChanged() }
    }
    @Published var isSmartSongCompensationEnabled = true {
        didSet {
            guard !isRestoring else { return }
            configureSmartAnalysis()
            if !isSmartSongCompensationEnabled {
                resetSmartCompensation()
            }
            saveProfessionalState()
        }
    }
    @Published var isDynamicEQEnabled = true {
        didSet { dynamicEQSettingChanged() }
    }
    @Published var isMultibandDynamicsEnabled = true {
        didSet { multibandSettingChanged() }
    }
    @Published var isParametricEQEnabled = false {
        didSet { parametricSettingChanged() }
    }
    @Published var parametricBands: [ParametricEQBand] = [] {
        didSet { parametricSettingChanged() }
    }
    @Published var dynamicEQBands: [DynamicEQBand] = DynamicEQBand.monoDefaults {
        didSet { dynamicEQSettingChanged() }
    }
    @Published var multibandConfiguration = MultibandDynamicsConfiguration(isEnabled: true) {
        didSet { multibandSettingChanged() }
    }
    @Published var monoEffectTuning = MonoEffectTuningConfiguration.neutral {
        didSet { monoEffectTuningChanged() }
    }
    @Published var customPresetPreampDB: Float = 0 {
        didSet {
            // Keep this guard before the corrective assignment. The previous order
            // could recurse indefinitely while restoring an out-of-range value.
            guard !isRestoring else { return }
            let clamped = Self.clampedPreamp(customPresetPreampDB)
            if abs(clamped - customPresetPreampDB) > 0.001 {
                customPresetPreampDB = clamped
                return
            }
            headroomSettingChanged()
        }
    }
    @Published private var presetPreampOverrides: [String: Float] = [:] {
        didSet { headroomSettingChanged() }
    }
    @Published var selectedHeadphoneProfileID: String = "off" {
        didSet { calibrationSettingChanged() }
    }
    @Published var headphoneProfiles: [MonoHeadphoneCorrectionProfile] = [] {
        didSet { calibrationSettingChanged() }
    }

    private var currentOutputUID: String = ""
    private var smartSpectrumAverage = Array(repeating: Float(0), count: 10)
    private var smartSpectrumFrames = 0
    private var smartSongIdentifier: String?
    private var lastSmartUpdate = Date.distantPast
    private var isSafetyLimiterActive = false
    private var preAIProcessingSnapshot: AIProcessingSnapshot?
    
    // MARK: - Published
    
    @Published var isEnabled: Bool = false {
        didSet {
            guard !isRestoring else { return }
            if !isEnabled {
                isAuditioningReference = false
                PlayerManager.shared.equalizer.setProcessingEnabled(false)
                PlayerManager.shared.equalizer.reset()
                PlayerManager.shared.audioEffects.applyMonoTuning(
                    .neutral,
                    bassGain: 0,
                    trebleGain: 0,
                    surroundLevel: 0,
                    reverbLevel: 0,
                    stereoWidth: 1
                )
                PlayerManager.shared.setPitch(0)
                disableSafetyMeasures()
                saveAudioEffectsState()
            } else {
                PlayerManager.shared.equalizer.setProcessingEnabled(true)
                if let preset = currentPreset {
                    applyPresetCurve(preset)
                } else if customGains.contains(where: { abs($0) > 0.001 }) {
                    applyCustomGains()
                } else {
                    PlayerManager.shared.equalizer.setGraphicMode(graphicEQMode, gainsDB: customGains)
                }
                applyProfessionalConfiguration()
                applyMonoEffectTuning()
                updateSafetyLimiter()
            }
            configureSmartAnalysis()
            saveState()
        }
    }
    
    @Published var currentPreset: EQPreset? = nil {
        didSet {
            guard !isRestoring else { return }
            isAuditioningReference = false
            if isEnabled, let preset = currentPreset {
                applyPresetCurve(preset)
                applyProfessionalConfiguration()
                updateSafetyLimiter()
            }
            saveState()
        }
    }

    /// 10 段为默认规格；32 段是用户主动选择的精细图示均衡器。
    @Published private(set) var graphicEQMode: GraphicEQMode = .tenBand
    private var tenBandCustomGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var thirtyTwoBandCustomGains = Array(repeating: Float(0), count: GraphicEQMode.thirtyTwoBand.bandCount)
    
    @Published var customGains: [Float] = Array(repeating: 0, count: 10) {
        didSet {
            guard !isRestoring else { return }
            if graphicEQMode == .tenBand {
                tenBandCustomGains = graphicEQMode.normalizedGains(customGains)
            } else {
                thirtyTwoBandCustomGains = graphicEQMode.normalizedGains(customGains)
            }
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
    
    /// 10 段与 32 段使用两份独立资源，避免运行时把内置预设临时插值。
    private static func loadBuiltInPresets() -> [EQPreset] {
        let tenBand = loadPresetResource(named: "eq_presets", fallback: embeddedFallbackPresets)
        let thirtyTwoBand = loadPresetResource(named: "eq_presets_32", fallback: embeddedFallback32Presets)
        return tenBand + thirtyTwoBand
    }

    private static func loadPresetResource(named resourceName: String, fallback: [EQPreset]) -> [EQPreset] {
        var candidateURLs: [URL?] = [
            Bundle.main.url(forResource: resourceName, withExtension: "json"),
            Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources")
        ]
#if SWIFT_PACKAGE
        candidateURLs.append(Bundle.module.url(forResource: resourceName, withExtension: "json"))
        candidateURLs.append(Bundle.module.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources"))
#endif
        guard let url = candidateURLs.compactMap({ $0 }).first else {
            AppLogger.warning("[EQManager] Bundle 中未找到 \(resourceName).json")
            return fallback
        }
        guard FileManager.default.fileExists(atPath: url.path),
              let data = FileManager.default.contents(atPath: url.path),
              !data.isEmpty else {
            AppLogger.warning("[EQManager] \(resourceName).json 不存在或为空")
            return fallback
        }
        do {
            let presets = try JSONDecoder().decode([EQPreset].self, from: data)
            AppLogger.debug("[EQManager] 从 \(resourceName).json 加载了 \(presets.count) 个内置预设")
            return presets
        } catch {
            AppLogger.warning("[EQManager] \(resourceName).json 解码失败: \(error)")
            return fallback
        }
    }
    
    /// 内嵌兜底预设（当 JSON 文件无法加载时使用）
    private static let embeddedFallbackPresets: [EQPreset] = [
        EQPreset(id: "flat", name: String(localized: "平坦"), category: .flat, description: String(localized: "基准监听曲线，不做任何染色，适合对比和校准听感"), gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], preampDB: 0),
        EQPreset(id: "pop", name: String(localized: "流行"), category: .genre, description: String(localized: "低频结实、主唱清楚、高频通透，中频不过度后退"), gains: [0.8, 1.3, 0.8, -0.4, -0.7, -0.2, 0.8, 1.1, 0.8, 0.6], preampDB: -1.7, loudnessCompensationDB: -0.3),
        EQPreset(id: "rock", name: String(localized: "摇滚"), category: .genre, description: String(localized: "收紧浑浊区，强化军鼓、吉他边缘与鼓组冲击"), gains: [0.5, 1.2, 1.0, -0.5, -1.0, 0.2, 1.2, 1.5, 0.7, 0.0], preampDB: -1.9, loudnessCompensationDB: -0.3),
        EQPreset(id: "vocal_enhance", name: String(localized: "人声增强"), category: .vocal, description: String(localized: "削减低频遮挡，集中提升 1-4kHz 咬字与存在感"), gains: [-2.0, -1.5, -0.7, -0.4, 0.0, 0.8, 1.6, 1.2, 0.0, -0.5], preampDB: -2.0, loudnessCompensationDB: -0.2),
        EQPreset(id: "bass_boost", name: String(localized: "低音增强"), category: .scene, description: String(localized: "以 62Hz 为核心增加下潜和鼓点重量，同时控制中低频发轰"), gains: [2.4, 2.8, 1.8, 0.3, -0.6, -0.5, -0.3, -0.3, -0.2, -0.2], preampDB: -3.2, loudnessCompensationDB: -0.1),
    ]

    private static let embeddedFallback32Presets: [EQPreset] = [
        EQPreset(id: "flat_32", familyID: "flat", name: String(localized: "平坦"), category: .flat, description: String(localized: "基准监听曲线，不做任何染色，适合对比和校准听感"), gains: Array(repeating: 0, count: 32), presetType: .graphic32, preampDB: 0),
        EQPreset(id: "pop_32", familyID: "pop", name: String(localized: "流行"), category: .genre, description: String(localized: "低频结实、主唱清楚、高频通透，中频不过度后退"), gains: [0.55, 0.55, 0.5, 0.45, 0.55, 0.9, 1.15, 0.9, 0.75, 0.8, 0.45, -0.05, -0.3, -0.3, -0.45, -0.6, -0.4, -0.2, -0.15, 0.05, 0.45, 0.75, 0.65, 0.8, 1.1, 0.85, 0.75, 0.85, 0.55, 0.35, 0.5, 0.8], presetType: .graphic32, preampDB: -2, loudnessCompensationDB: -0.3),
        EQPreset(id: "rock_32", familyID: "rock", name: String(localized: "摇滚"), category: .genre, description: String(localized: "收紧浑浊区，强化军鼓、吉他边缘与鼓组冲击"), gains: [0.35, 0.35, 0.35, 0.35, 0.45, 0.8, 1.1, 0.9, 0.8, 0.95, 0.5, -0.05, -0.35, -0.4, -0.6, -0.8, -0.45, -0.05, 0.2, 0.35, 0.75, 1.15, 0.95, 1.1, 1.45, 1.05, 0.8, 0.8, 0.5, 0.2, 0.1, 0], presetType: .graphic32, preampDB: -2.3, loudnessCompensationDB: -0.3),
        EQPreset(id: "vocal_enhance_32", familyID: "vocal_enhance", name: String(localized: "人声增强"), category: .vocal, description: String(localized: "削减低频遮挡，集中提升 1-4kHz 咬字与存在感"), gains: [-1.35, -1.35, -1.15, -0.9, -0.8, -1.05, -1.35, -1.05, -0.8, -0.8, -0.6, -0.4, -0.4, -0.25, -0.05, 0.05, 0.2, 0.5, 0.8, 0.8, 1.1, 1.5, 1.15, 1, 1.2, 0.75, 0.3, 0.15, 0.05, -0.05, -0.35, -0.65], presetType: .graphic32, preampDB: -2.5, loudnessCompensationDB: -0.2),
        EQPreset(id: "bass_boost_32", familyID: "bass_boost", name: String(localized: "低音增强"), category: .scene, description: String(localized: "以 62Hz 为核心增加下潜和鼓点重量，同时控制中低频发轰"), gains: [1.65, 1.65, 1.5, 1.25, 1.25, 1.95, 2.55, 2, 1.7, 1.9, 1.25, 0.6, 0.45, 0.15, -0.2, -0.5, -0.4, -0.4, -0.45, -0.35, -0.3, -0.3, -0.25, -0.25, -0.3, -0.25, -0.2, -0.2, -0.15, -0.1, -0.15, -0.25], presetType: .graphic32, preampDB: -3.9, loudnessCompensationDB: -0.2),
    ]
    
    // MARK: - Init

    private static func clampedProfessionalIntensity(_ value: Float) -> Float {
        guard value.isFinite else { return 1.3 }
        return min(max(value, 0.6), 2.1)
    }

    private static func clampedPreamp(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, -18), 0)
    }
    
    private init() {
        isRestoring = true
        restoreState()
        restoreProfessionalState()
        restoreAIProcessingSnapshot()
        isRestoring = false
        handleAudioRouteChanged()
        PlayerManager.shared.equalizer.setProcessingEnabled(isEnabled)
        applyProfessionalConfiguration()
        applyMonoEffectTuning()
        configureSmartAnalysis()
        updateSafetyLimiter()
    }
    
    // MARK: - 所有预设（内置 + 自定义）
    
    var allPresets: [EQPreset] {
        builtInPresets + customPresets
    }

    var isAIManagedPresetActive: Bool {
        currentPreset?.id.hasPrefix("ai_") == true
    }
    
    func presets(for category: EQPresetCategory) -> [EQPreset] {
        if category == .custom {
            return customPresets
        }
        return builtInPresets.filter {
            $0.category == category && $0.presetType.graphicMode == graphicEQMode
        }
    }
    
    // MARK: - 应用预设

    var graphicBandFrequencies: [Float] { graphicEQMode.centerFrequencies }
    var graphicBandLabels: [String] { graphicEQMode.frequencyLabels }

    private func builtInPreset(familyID: String, mode: GraphicEQMode) -> EQPreset? {
        builtInPresets.first {
            !$0.isCustom && $0.familyID == familyID && $0.presetType.graphicMode == mode
        }
    }

    private func matchingBuiltInPreset(_ preset: EQPreset?, mode: GraphicEQMode) -> EQPreset? {
        guard let preset else { return nil }
        guard !preset.isCustom else { return preset }
        return builtInPreset(familyID: preset.familyID, mode: mode) ?? preset
    }

    func setGraphicEQMode(_ mode: GraphicEQMode) {
        guard mode != graphicEQMode else { return }
        if isAIManagedPresetActive {
            restoreProcessingBeforeAI(reason: "manual-band-mode")
        }

        if graphicEQMode == .tenBand {
            tenBandCustomGains = GraphicEQMode.tenBand.normalizedGains(customGains)
        } else {
            thirtyTwoBandCustomGains = GraphicEQMode.thirtyTwoBand.normalizedGains(customGains)
        }

        isRestoring = true
        graphicEQMode = mode
        customGains = mode == .tenBand ? tenBandCustomGains : thirtyTwoBandCustomGains
        currentPreset = matchingBuiltInPreset(currentPreset, mode: mode)
        isRestoring = false

        if isEnabled {
            if let preset = currentPreset, preset.id != "custom" {
                applyPresetCurve(preset)
            } else {
                applyCustomGains()
            }
            applyProfessionalConfiguration()
            updateSafetyLimiter()
        } else {
            PlayerManager.shared.equalizer.setGraphicMode(mode, gainsDB: customGains)
        }
        saveState()
    }

    private func applyPresetCurve(_ preset: EQPreset, mode: GraphicEQMode? = nil) {
        let targetMode = mode ?? graphicEQMode
        PlayerManager.shared.equalizer.setGraphicMode(
            targetMode,
            gainsDB: preset.gains(in: targetMode)
        )
    }
    
    func applyPreset(_ preset: EQPreset) {
        if isAIManagedPresetActive, !preset.id.hasPrefix("ai_") {
            restoreProcessingBeforeAI(reason: "manual-preset")
        }
        let resolvedPreset = matchingBuiltInPreset(preset, mode: graphicEQMode) ?? preset
        currentPreset = resolvedPreset
        if !isEnabled {
            isEnabled = true
        }
        if !resolvedPreset.isCustom {
            applyBuiltInProcessingProfile(resolvedPreset)
        }
        updateSafetyLimiter()
        saveAudioEffectsState()
    }
    
    func applyFlat() {
        if isAIManagedPresetActive {
            restoreProcessingBeforeAI(reason: "manual-flat")
        }
        currentPreset = builtInPreset(familyID: "flat", mode: graphicEQMode)
        if currentPreset == nil {
            PlayerManager.shared.equalizer.setGraphicMode(
                graphicEQMode,
                gainsDB: Array(repeating: 0, count: graphicEQMode.bandCount)
            )
            applyProfessionalConfiguration()
        }
        if let currentPreset {
            applyBuiltInProcessingProfile(currentPreset)
        }
        updateSafetyLimiter()
        saveAudioEffectsState()
    }

    private func applyBuiltInProcessingProfile(_ preset: EQPreset) {
        let player = PlayerManager.shared
        let profile = preset.processingProfile
        let wasRestoring = isRestoring
        isRestoring = true
        monoEffectTuning = profile.effects
        isRestoring = wasRestoring
        player.audioEffects.applyMonoTuning(
            profile.effects,
            bassGain: profile.bassGain,
            trebleGain: profile.trebleGain,
            surroundLevel: preset.surroundLevel,
            reverbLevel: preset.reverbLevel,
            stereoWidth: preset.stereoWidth
        )
    }

    /// 切换歌曲时撤销上一首 AI 方案，恢复用户在开启 AI 调音前的处理链。
    func prepareForAIAnalysis(songIdentifier: String) {
        restoreProcessingBeforeAI(reason: "track-changed")
        beginSongAnalysis(identifier: songIdentifier)
        configureSmartAnalysis()
    }

    /// 关闭 AI 或切换歌曲时恢复 AI 覆盖前的完整用户处理链。
    func restoreProcessingBeforeAI(reason: String) {
        guard preAIProcessingSnapshot != nil || isAIManagedPresetActive else { return }
        stopLoudnessMatchedReferenceAudition()

        let previousPreset = currentPreset?.name ?? "none"
        let snapshot = preAIProcessingSnapshot ?? neutralAIProcessingSnapshot()
        isRestoring = true
        isEnabled = snapshot.isEnabled
        let restoredMode = snapshot.graphicEQMode
            ?? (snapshot.customGains.count == GraphicEQMode.thirtyTwoBand.bandCount ? .thirtyTwoBand : .tenBand)
        graphicEQMode = restoredMode
        currentPreset = matchingBuiltInPreset(snapshot.currentPreset, mode: restoredMode)
        tenBandCustomGains = GraphicEQMode.tenBand.normalizedGains(
            snapshot.tenBandCustomGains ?? (restoredMode == .tenBand ? snapshot.customGains : [])
        )
        thirtyTwoBandCustomGains = GraphicEQMode.thirtyTwoBand.normalizedGains(
            snapshot.thirtyTwoBandCustomGains ?? (restoredMode == .thirtyTwoBand ? snapshot.customGains : [])
        )
        customGains = restoredMode == .tenBand ? tenBandCustomGains : thirtyTwoBandCustomGains
        customPresetPreampDB = snapshot.customPresetPreampDB
        professionalProcessingIntensity = snapshot.professionalProcessingIntensity
        isLoudnessMatchingEnabled = snapshot.isLoudnessMatchingEnabled
        isOutputCalibrationEnabled = snapshot.isOutputCalibrationEnabled
        isSmartSongCompensationEnabled = snapshot.isSmartSongCompensationEnabled
        isDynamicEQEnabled = snapshot.isDynamicEQEnabled
        dynamicEQBands = snapshot.dynamicEQBands
        isMultibandDynamicsEnabled = snapshot.isMultibandDynamicsEnabled
        multibandConfiguration = snapshot.multibandConfiguration
        isParametricEQEnabled = snapshot.isParametricEQEnabled
        parametricBands = snapshot.parametricBands
        monoEffectTuning = snapshot.monoEffectTuning ?? .neutral
        adaptiveGains = Array(repeating: 0, count: 10)
        isRestoring = false

        let player = PlayerManager.shared
        player.equalizer.reset()
        player.equalizer.setProcessingEnabled(snapshot.isEnabled)
        if snapshot.isEnabled {
            if let preset = snapshot.currentPreset, preset.id != "custom" {
                applyPresetCurve(preset, mode: restoredMode)
            } else {
                player.equalizer.setGraphicMode(restoredMode, gainsDB: customGains)
            }
        } else {
            player.equalizer.setGraphicMode(restoredMode, gainsDB: customGains)
        }
        player.audioEffects.applyMonoTuning(
            effectiveMonoEffectTuningForCurrentOutput(),
            bassGain: snapshot.bassGain,
            trebleGain: snapshot.trebleGain,
            surroundLevel: snapshot.surroundLevel,
            reverbLevel: snapshot.reverbLevel,
            stereoWidth: snapshot.stereoWidth
        )

        applyProfessionalConfiguration()
        applyMonoEffectTuning()
        configureSmartAnalysis()
        updateSafetyLimiter()
        preAIProcessingSnapshot = nil
        UserDefaults.standard.removeObject(forKey: Self.aiProcessingSnapshotKey)
        saveState()
        saveProfessionalState()
        saveAudioEffectsState()

        AppLogger.info(
            "[EQManager] Restored processing before AI preset=\(previousPreset) reason=\(reason)",
            step: "ai-tuning.restore"
        )
    }

    /// 将 AI 生成的完整 Mono 处理方案一次性写入引擎，避免逐项触发重复重建 DSP 链。
    func applyAIConfiguration(
        _ proposal: AIEqualizerProposal,
        spatialOverride: AIEqualizerSpatialConfiguration? = nil
    ) {
        stopLoudnessMatchedReferenceAudition()
        captureProcessingBeforeAIIfNeeded()

        let professional = proposal.professional
        let resolvedSpatial = spatialOverride ?? proposal.spatial
        let dynamicBands = professional.dynamicEQ.bands.map {
            DynamicEQBand(
                frequency: $0.frequency,
                q: $0.q,
                thresholdDB: $0.thresholdDB,
                ratio: $0.ratio,
                maxReductionDB: $0.maxReductionDB,
                attackMS: $0.attackMS,
                releaseMS: $0.releaseMS
            )
        }
        let parametricBands = professional.parametricEQ.bands.compactMap { band -> ParametricEQBand? in
            guard let type = ParametricEQFilterType(rawValue: band.type) else { return nil }
            return ParametricEQBand(
                type: type,
                frequency: band.frequency,
                gainDB: band.gainDB,
                q: band.q
            )
        }
        let multiband = professional.multiband
        let multibandConfiguration = MultibandDynamicsConfiguration(
            isEnabled: multiband.enabled,
            lowCrossoverHz: multiband.lowCrossoverHz,
            highCrossoverHz: multiband.highCrossoverHz,
            thresholdsDB: multiband.thresholdsDB,
            ratios: multiband.ratios,
            maxReductionDB: multiband.maxReductionDB,
            attackMS: multiband.attackMS,
            releaseMS: multiband.releaseMS
        )
        let generatedPreset = EQPreset(
            id: "ai_\(proposal.songID)",
            name: proposal.profileName,
            category: .custom,
            description: proposal.profileSpecificSummary,
            gains: proposal.gains,
            isCustom: true,
            presetType: proposal.graphicEQMode == .tenBand ? .standard10 : .graphic32,
            preampDB: proposal.preampDB
        )

        isRestoring = true
        graphicEQMode = proposal.graphicEQMode
        customGains = proposal.gains
        if proposal.graphicEQMode == .tenBand {
            tenBandCustomGains = proposal.gains
        } else {
            thirtyTwoBandCustomGains = proposal.gains
        }
        customPresetPreampDB = proposal.preampDB
        currentPreset = generatedPreset
        professionalProcessingIntensity = professional.processingIntensity
        isOutputCalibrationEnabled = proposal.calibration.outputCalibrationEnabled
        isLoudnessMatchingEnabled = proposal.calibration.loudnessMatchingEnabled
        isSmartSongCompensationEnabled = proposal.calibration.smartSongCompensationEnabled
        isDynamicEQEnabled = professional.dynamicEQ.enabled
        dynamicEQBands = dynamicBands.isEmpty ? DynamicEQBand.monoDefaults : dynamicBands
        isMultibandDynamicsEnabled = multiband.enabled
        self.multibandConfiguration = multibandConfiguration
        isParametricEQEnabled = professional.parametricEQ.enabled && !parametricBands.isEmpty
        self.parametricBands = parametricBands
        monoEffectTuning = proposal.effects
        isEnabled = true
        isRestoring = false

        let player = PlayerManager.shared
        player.equalizer.setProcessingEnabled(true)
        applyPresetCurve(generatedPreset, mode: proposal.graphicEQMode)
        let effectiveEffects = effectiveMonoEffectTuningForCurrentOutput()
        player.audioEffects.applyMonoTuning(
            effectiveEffects,
            bassGain: proposal.tone.bassGain,
            trebleGain: proposal.tone.trebleGain,
            surroundLevel: resolvedSpatial.surroundLevel,
            reverbLevel: resolvedSpatial.reverbLevel,
            stereoWidth: resolvedSpatial.stereoWidth
        )
        player.audioRepair.configureOutputSafety(
            limiterEnabled: effectiveEffects.finalLimiterEnabled,
            ceilingDB: effectiveEffects.finalLimiterCeilingDB,
            transitionProtectionEnabled: false,
            outputGainDB: player.audioRepair.outputGainDB,
            perceptualMakeupDB: player.audioRepair.perceptualMakeupDB
        )
        isSafetyLimiterActive = effectiveEffects.finalLimiterEnabled

        beginSongAnalysis(identifier: player.currentSong.map { "\($0.musicSource.rawValue):\($0.id)" })
        applyProfessionalConfiguration()
        configureSmartAnalysis()
        updateSafetyLimiter()
        saveState()
        saveProfessionalState()
        saveAudioEffectsState()
    }
    
    // MARK: - 自定义增益
    
    func setCustomGain(_ gain: Float, at index: Int) {
        guard customGains.indices.contains(index) else { return }
        customGains[index] = EQBandGain.clamped(gain)
        if isEnabled {
            PlayerManager.shared.equalizer.setGraphicGain(customGains[index], at: index)
            updateSafetyLimiter()
        }
    }
    
    private func applyCustomGains() {
        PlayerManager.shared.equalizer.setGraphicMode(graphicEQMode, gainsDB: customGains)
        updateSafetyLimiter()
    }

    // MARK: - Mono 专业校准

    func handleAudioRouteChanged() {
        let output = AVAudioSession.sharedInstance().currentRoute.outputs.first
        currentOutputName = output?.portName ?? String(localized: "eq_current_device")
        currentOutputUID = output?.uid ?? "unknown-output"
        currentOutputKind = Self.outputKind(for: output?.portType)
        applyProfessionalConfiguration()
        if isEnabled { applyMonoEffectTuning() }
        updateSafetyLimiter()
        let presetName = currentPreset?.name ?? "none"
        let limiterCeiling = PlayerManager.shared.audioRepair.outputLimiterCeilingDB
        AppLogger.info(
            "[EQManager] Output route kind=\(currentOutputKind.rawValue) port=\(output?.portType.rawValue ?? "none") name=\(currentOutputName) preset=\(presetName) enabled=\(isEnabled) preamp=\(String(format: "%.2f", preampDB))dB limiter=\(isSafetyLimiterActive) ceiling=\(String(format: "%.2f", limiterCeiling))dBFS",
            step: "audio-output.route-safety"
        )
    }

    func addParametricBand() {
        guard parametricBands.count < 12 else { return }
        parametricBands.append(
            ParametricEQBand(
                type: .peak,
                frequency: parametricBands.isEmpty ? 1_000 : min((parametricBands.last?.frequency ?? 500) * 1.6, 16_000),
                gainDB: 0,
                q: 1
            )
        )
    }

    func toggleLoudnessMatchedReference() {
        guard isEnabled else { return }
        isAuditioningReference.toggle()
        if isAuditioningReference {
            let sourceGains = currentPreset?.id == "custom" || currentPreset == nil
                ? customGains
                : (currentPreset?.gains(in: graphicEQMode) ?? customGains)
            let perceivedCurveGain = zip(sourceGains, Self.loudnessWeights(for: graphicEQMode))
                .reduce(Float(0)) { $0 + $1.0 * $1.1 }
            PlayerManager.shared.equalizer.setGraphicMode(
                graphicEQMode,
                gainsDB: Array(repeating: 0, count: graphicEQMode.bandCount)
            )
            // 参考声必须旁路完整专业链路，否则动态处理仍留在 B 声中，A/B 差异会被掩盖。
            applyProfessionalConfiguration()
            applyMonoEffectTuning()
            PlayerManager.shared.equalizer.setPreampDB(
                min(0, max(-18, preampDB + perceivedCurveGain))
            )
        } else {
            if let preset = currentPreset, preset.id != "custom" {
                applyPresetCurve(preset)
            } else {
                PlayerManager.shared.equalizer.setGraphicMode(graphicEQMode, gainsDB: customGains)
            }
            applyProfessionalConfiguration()
            applyMonoEffectTuning()
            // 参考声只改了 DSP 的目标前级，不会同步 Published 值；返回 A 声时必须显式恢复。
            PlayerManager.shared.equalizer.setPreampDB(preampDB)
            updateSafetyLimiter()
        }
    }

    func stopLoudnessMatchedReferenceAudition() {
        guard isAuditioningReference else { return }
        toggleLoudnessMatchedReference()
    }

    func removeParametricBand(id: UUID) {
        parametricBands.removeAll { $0.id == id }
    }

    func createHeadphoneProfileForCurrentOutput() {
        let normalizedName = currentOutputName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = MonoHeadphoneCorrectionProfile(
            id: "headphone_\(UUID().uuidString)",
            name: normalizedName.isEmpty ? String(localized: "eq_custom_headphone") : normalizedName,
            matchedDeviceName: normalizedName,
            matchedDeviceUID: currentOutputUID,
            gains: Array(repeating: 0, count: 10),
            isCustom: true
        )
        headphoneProfiles.append(profile)
        selectedHeadphoneProfileID = profile.id
    }

    func deleteHeadphoneProfile(id: String) {
        headphoneProfiles.removeAll { $0.id == id }
        if selectedHeadphoneProfileID == id {
            selectedHeadphoneProfileID = "off"
        }
    }

    func setHeadphoneCorrectionGain(_ gain: Float, at index: Int) {
        guard index >= 0, index < 10,
              let profileIndex = headphoneProfiles.firstIndex(where: { $0.id == selectedHeadphoneProfileID })
        else { return }
        headphoneProfiles[profileIndex].gains[index] = min(max(gain, -6), 6)
    }

    var currentPresetPreampDB: Float {
        if let id = currentPreset?.id, let override = presetPreampOverrides[id] {
            return override
        }
        if currentPreset?.id == "custom" || currentPreset == nil {
            return customPresetPreampDB
        }
        return currentPreset?.preampDB ?? 0
    }

    func setCurrentPresetPreampDB(_ value: Float) {
        let clamped = min(max(value, -18), 0)
        if let id = currentPreset?.id, id != "custom" {
            presetPreampOverrides[id] = clamped
        } else {
            customPresetPreampDB = clamped
        }
    }

    func beginSongAnalysis(identifier: String?) {
        guard smartSongIdentifier != identifier else { return }
        smartSongIdentifier = identifier
        smartSpectrumAverage = Array(repeating: 0, count: 10)
        smartSpectrumFrames = 0
        lastSmartUpdate = .distantPast
        adaptiveGains = Array(repeating: 0, count: 10)
        applyCombinedAdaptiveGains()
    }

    private func headroomSettingChanged() {
        guard !isRestoring else { return }
        updateSafetyLimiter()
        saveProfessionalState()
    }

    private func calibrationSettingChanged() {
        guard !isRestoring else { return }
        applyProfessionalConfiguration()
        updateSafetyLimiter()
        saveProfessionalState()
    }

    private func parametricSettingChanged() {
        guard !isRestoring else { return }
        applyProfessionalConfiguration()
        updateSafetyLimiter()
        saveProfessionalState()
    }

    private func dynamicEQSettingChanged() {
        guard !isRestoring else { return }
        applyProfessionalConfiguration()
        saveProfessionalState()
    }

    private func multibandSettingChanged() {
        guard !isRestoring else { return }
        applyProfessionalConfiguration()
        saveProfessionalState()
    }

    private func monoEffectTuningChanged() {
        guard !isRestoring else { return }
        if isEnabled { applyMonoEffectTuning() }
        updateSafetyLimiter()
        saveProfessionalState()
    }

    private func applyMonoEffectTuning() {
        let player = PlayerManager.shared
        let configuration = isAuditioningReference
            ? .neutral
            : effectiveMonoEffectTuningForCurrentOutput()
        player.audioEffects.applyMonoTuning(configuration)
        let preservesAILevel = isAIManagedPresetActive && !isAuditioningReference
        player.audioRepair.configureOutputSafety(
            limiterEnabled: isEnabled && configuration.finalLimiterEnabled,
            ceilingDB: configuration.finalLimiterCeilingDB,
            transitionProtectionEnabled: false,
            outputGainDB: preservesAILevel ? player.audioRepair.outputGainDB : 0,
            perceptualMakeupDB: preservesAILevel ? player.audioRepair.perceptualMakeupDB : 0
        )
        isSafetyLimiterActive = isEnabled && configuration.finalLimiterEnabled
    }

    private func effectiveMonoEffectTuningForCurrentOutput() -> MonoEffectTuningConfiguration {
        var configuration = monoEffectTuning
        if isAIManagedPresetActive {
            // FFmpeg loudnorm may internally upsample to 192 kHz when used
            // without a full offline measurement pass. Mono already performs
            // measured loudness matching through its realtime EQ/preamp stage.
            configuration.loudnessNormalizationEnabled = false
            if isDynamicEQEnabled || isMultibandDynamicsEnabled {
                configuration.compressorEnabled = false
            }
        }
        switch currentOutputKind {
        case .bluetooth:
            // Bluetooth codecs are less tolerant of inter-sample peaks and
            // phase tricks than the local Float32 chain. Haas widening and
            // excessive synthesized harmonics are the most common source of
            // the reported "interference" texture, especially on vocal-heavy
            // material. Preserve the EQ intent while constraining only the
            // codec-hostile mastering layer.
            configuration.haasEnabled = false
            configuration.exciterAmountDB = min(configuration.exciterAmountDB, 0.3)
            configuration.compressorMakeupDB = min(configuration.compressorMakeupDB, 0.3)
            configuration.finalLimiterCeilingDB = min(
                configuration.finalLimiterCeilingDB,
                -1.5
            )
        case .wired, .usb:
            break
        default:
            configuration.bs2bEnabled = false
            configuration.crossfeedEnabled = false
            configuration.haasEnabled = false
        }
        return configuration
    }

    private func applyProfessionalConfiguration() {
        let equalizer = PlayerManager.shared.equalizer
        let bypassProfessionalChain = isAuditioningReference
        let zeroGains = Array(repeating: Float(0), count: 10)
        let aiManaged = isAIManagedPresetActive
        let dynamicLimit = graphicEQMode == .thirtyTwoBand ? 3 : 4
        let parametricLimit = graphicEQMode == .thirtyTwoBand ? 3 : 6
        let dynamicEnabled = !bypassProfessionalChain && isDynamicEQEnabled
        let multibandEnabled = !bypassProfessionalChain
            && isMultibandDynamicsEnabled
            && (!aiManaged || !dynamicEnabled)

        equalizer.setCalibrationGains(bypassProfessionalChain ? zeroGains : effectiveCalibrationGains)
        let smartLayer = isSmartSongCompensationEnabled ? adaptiveGains : zeroGains
        equalizer.setAdaptiveGains(bypassProfessionalChain ? zeroGains : smartLayer)
        equalizer.setParametricBands(
            !bypassProfessionalChain && isParametricEQEnabled
                ? Array(parametricBands.prefix(aiManaged ? parametricLimit : parametricBands.count))
                : []
        )
        equalizer.setDynamicEQ(
            enabled: dynamicEnabled,
            bands: Array(effectiveDynamicEQBands.prefix(aiManaged ? dynamicLimit : dynamicEQBands.count))
        )
        var dynamics = effectiveMultibandConfiguration
        dynamics.isEnabled = multibandEnabled
        equalizer.setMultibandDynamics(dynamics)
    }

    private var effectiveDynamicEQBands: [DynamicEQBand] {
        let amount = professionalProcessingIntensity
        return dynamicEQBands.map { source in
            var band = source
            band.thresholdDB = max(-60, source.thresholdDB - 4 * (amount - 1))
            band.ratio = min(10, 1 + (source.ratio - 1) * amount)
            band.maxReductionDB = min(12, source.maxReductionDB * amount)
            return band
        }
    }

    private var effectiveMultibandConfiguration: MultibandDynamicsConfiguration {
        let amount = professionalProcessingIntensity
        var configuration = multibandConfiguration
        configuration.thresholdsDB = configuration.thresholdsDB.map {
            max(-60, $0 - 3 * (amount - 1))
        }
        configuration.ratios = configuration.ratios.map {
            min(6, 1 + ($0 - 1) * amount)
        }
        configuration.maxReductionDB = configuration.maxReductionDB.map {
            min(8, $0 * amount)
        }
        return configuration
    }

    private var effectiveCalibrationGains: [Float] {
        var gains = isOutputCalibrationEnabled
            ? currentOutputKind.defaultCalibration
            : Array(repeating: 0, count: 10)
        guard let profile = resolvedHeadphoneProfile else { return gains }
        for index in 0..<min(gains.count, profile.gains.count) {
            gains[index] = min(max(gains[index] + profile.gains[index], -6), 6)
        }
        return gains
    }

    private var resolvedHeadphoneProfile: MonoHeadphoneCorrectionProfile? {
        if selectedHeadphoneProfileID == "off" { return nil }
        if selectedHeadphoneProfileID == "auto" {
            let routeName = currentOutputName.lowercased()
            return headphoneProfiles.first {
                let match = $0.matchedDeviceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return (!$0.matchedDeviceUID.isEmpty && $0.matchedDeviceUID == currentOutputUID)
                    || (!match.isEmpty && routeName.contains(match))
            }
        }
        return headphoneProfiles.first { $0.id == selectedHeadphoneProfileID }
    }

    private func configureSmartAnalysis() {
        // 必须用 pre-effect 分析器：可视化用的 spectrumAnalyzer 取自 mixer tap，
        // 读到的是 EQ/效果器处理后的频谱。用它做补偿会把自己的修正当成
        // 素材缺陷继续修，和 AI 托管曲线形成反馈回路。
        let analyzer = PlayerManager.shared.streamPlayer.analysisSpectrumAnalyzer
        guard isEnabled, isSmartSongCompensationEnabled else {
            analyzer.onCalibrationSpectrum = nil
            analyzer.isCalibrationEnabled = false
            return
        }
        analyzer.onCalibrationSpectrum = { [weak self] magnitudes, sampleRate, rms in
            Task { @MainActor [weak self] in
                self?.processSmartSpectrum(magnitudes, sampleRate: sampleRate, rms: rms)
            }
        }
        analyzer.isCalibrationEnabled = true
    }

    private func processSmartSpectrum(_ magnitudes: [Float], sampleRate: Double, rms: Float) {
        guard isEnabled, isSmartSongCompensationEnabled, !isAuditioningReference,
              rms > 0.004, magnitudes.count > 32 else { return }

        let songID = PlayerManager.shared.currentSong.map { "\($0.musicSource.rawValue):\($0.id)" }
        if songID != smartSongIdentifier {
            beginSongAnalysis(identifier: songID)
        }
        guard Date().timeIntervalSince(lastSmartUpdate) >= 1.0 else { return }
        lastSmartUpdate = Date()

        let frequencies = EQBand.allCases.map { Double($0.centerFrequency) }
        let binWidth = sampleRate / Double(magnitudes.count * 2)
        var measured = Array(repeating: Float(-100), count: 10)
        for (index, frequency) in frequencies.enumerated() {
            let lower = frequency / sqrt(2)
            let upper = frequency * sqrt(2)
            let lowerBin = max(1, Int(lower / binWidth))
            let upperBin = min(magnitudes.count - 1, max(lowerBin, Int(upper / binWidth)))
            guard upperBin >= lowerBin else { continue }
            var energy: Float = 0
            for bin in lowerBin...upperBin {
                energy += magnitudes[bin] * magnitudes[bin]
            }
            measured[index] = 10 * log10f(max(energy / Float(upperBin - lowerBin + 1), 0.000_000_000_1))
        }

        if smartSpectrumFrames == 0 {
            smartSpectrumAverage = measured
        } else {
            for index in 0..<10 {
                smartSpectrumAverage[index] = smartSpectrumAverage[index] * 0.88 + measured[index] * 0.12
            }
        }
        smartSpectrumFrames += 1
        guard smartSpectrumFrames >= 4 else { return }

        let intensity = professionalProcessingIntensity
        var requested = Array(repeating: Float(0), count: 10)
        for index in 1..<9 {
            let neighborhood = (smartSpectrumAverage[index - 1] + smartSpectrumAverage[index + 1]) * 0.5
            let localDeviation = smartSpectrumAverage[index] - neighborhood
            requested[index] = min(max(-localDeviation * 0.2 * intensity, -1.5), min(1.2, 0.9 * intensity))
        }
        let subBassExcess = smartSpectrumAverage[0] - smartSpectrumAverage[1]
        requested[0] = subBassExcess > 5 ? max(-1.5, -(subBassExcess - 5) * 0.18 * intensity) : 0
        let airDeviation = smartSpectrumAverage[9] - smartSpectrumAverage[8]
        requested[9] = airDeviation > 4 ? max(-1.5, -(airDeviation - 4) * 0.16 * intensity) : 0

        // Never turn spectral analysis into an automatic loudness boost.
        let positiveMean = requested.reduce(0, +) / Float(requested.count)
        if positiveMean > 0 {
            requested = requested.map { min(max($0 - positiveMean, -1.5), 0.8) }
        }
        for index in 0..<10 {
            adaptiveGains[index] = adaptiveGains[index] * 0.72 + requested[index] * 0.28
        }
        applyCombinedAdaptiveGains()
        updateSafetyLimiter()
    }

    private func resetSmartCompensation() {
        smartSpectrumAverage = Array(repeating: 0, count: 10)
        smartSpectrumFrames = 0
        adaptiveGains = Array(repeating: 0, count: 10)
        applyCombinedAdaptiveGains()
        updateSafetyLimiter()
    }

    private func applyCombinedAdaptiveGains() {
        let zeroGains = Array(repeating: Float(0), count: 10)
        let smartLayer = isSmartSongCompensationEnabled ? adaptiveGains : zeroGains
        PlayerManager.shared.equalizer.setAdaptiveGains(isAuditioningReference ? zeroGains : smartLayer)
    }

    private static func outputKind(for port: AVAudioSession.Port?) -> MonoAudioOutputKind {
        switch port {
        case .builtInSpeaker, .builtInReceiver: return .builtInSpeaker
        case .headphones, .headsetMic, .lineOut: return .wired
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE: return .bluetooth
        case .carAudio: return .car
        case .airPlay: return .airPlay
        case .usbAudio, .displayPort: return .usb
        default: return .other
        }
    }

    // MARK: - 安全增益管理（前级补偿 + 限幅器）
    
    /// 根据当前 EQ 增益峰值和旋钮状态，自动调整前级补偿并启用安全限幅器
    func updateSafetyLimiter() {
        let effects = PlayerManager.shared.audioEffects
        let repair = PlayerManager.shared.audioRepair
        guard isEnabled else {
            disableSafetyMeasures()
            return
        }

        // The legacy FFmpeg limiter sits before Mono's realtime EQ. Keep it
        // disabled so final peak protection is owned by the post-EQ repair stage.
        effects.setLimiterEnabled(false)

        // A/B 参考声保持完整旁路；只保留切换时计算出的等响前级。
        if isAuditioningReference {
            if isSafetyLimiterActive {
                repair.configureOutputSafety(
                    limiterEnabled: false,
                    transitionProtectionEnabled: false
                )
                isSafetyLimiterActive = false
            }
            return
        }
        
        let userGains: [Float]
        if let preset = currentPreset, preset.id != "custom" {
            userGains = preset.gains(in: graphicEQMode)
        } else {
            userGains = customGains
        }
        var gains = Array(repeating: Float(0), count: graphicEQMode.bandCount)
        let calibration = graphicEQMode.resampledGains(effectiveCalibrationGains, from: .tenBand)
        let activeAdaptive = graphicEQMode.resampledGains(adaptiveGains, from: .tenBand)
        for index in gains.indices {
            let user = index < userGains.count ? userGains[index] : 0
            let device = index < calibration.count ? calibration[index] : 0
            let adaptive = isSmartSongCompensationEnabled && index < activeAdaptive.count ? activeAdaptive[index] : 0
            gains[index] = user + device + adaptive
        }
        
        let bassKnob = max(effects.bassGain, 0)
        let trebleKnob = max(effects.trebleGain, 0)
        let curvePeakBoost = Self.estimatedCurvePeakBoostDB(for: gains, mode: graphicEQMode)
        let parametricPeakBoost = isParametricEQEnabled
            ? Self.estimatedParametricPeakBoostDB(for: parametricBands)
            : 0
        let toneControlBoost = max(bassKnob, trebleKnob)
        // 使用效果器当前值，兼容用户在任何预设上手动叠加环绕或混响。
        let spatialHeadroom = max(
            effects.surroundLevel * 0.7,
            effects.reverbLevel * 0.45
        )
        let effectiveTuning = effectiveMonoEffectTuningForCurrentOutput()
        let enhancementHeadroom = (effectiveTuning.subboostEnabled ? effectiveTuning.subboostGainDB * 0.45 : 0)
            + (effectiveTuning.virtualBassEnabled ? effectiveTuning.virtualBassStrength * 0.25 : 0)
            + (effectiveTuning.exciterEnabled ? effectiveTuning.exciterAmountDB * 0.18 : 0)
            + (effectiveTuning.compressorEnabled ? max(0, effectiveTuning.compressorMakeupDB) : 0)
        let peakGain = curvePeakBoost
            + parametricPeakBoost
            + toneControlBoost
            + spatialHeadroom
            + enhancementHeadroom
        
        // 按完整级联曲线的峰值做前级补偿，而不是只看最高的单个滑块。
        // 额外保留 0.25 dB 余量，避免母带接近 0 dBFS 时频段叠加触发硬削波。
        // Lossy Bluetooth encoding can create inter-sample peaks even when the
        // decoded Float32 samples stay below 0 dBFS. Reserve a little more room
        // before the final limiter on that route without flattening the curve.
        let safetyMargin: Float = currentOutputKind == .bluetooth ? 0.75 : 0.35
        let safetyTrim: Float = peakGain > 0.1 ? -(peakGain + safetyMargin) : 0
        let presetTrim: Float
        if currentPreset?.id == "custom" || currentPreset == nil {
            presetTrim = customPresetPreampDB
        } else if let id = currentPreset?.id, let override = presetPreampOverrides[id] {
            presetTrim = override
        } else {
            presetTrim = currentPreset?.preampDB ?? safetyTrim
        }
        let perceivedBoost = zip(gains, Self.loudnessWeights(for: graphicEQMode))
            .reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let automaticLoudnessTrim = -max(perceivedBoost, 0)
        let loudnessTrim = isLoudnessMatchingEnabled
            ? (currentPreset?.loudnessCompensationDB ?? automaticLoudnessTrim)
            : 0
        let newPreamp = max(-18, min(safetyTrim, presetTrim, loudnessTrim))
        
        if abs(newPreamp - preampDB) > 0.05 {
            preampDB = newPreamp
            PlayerManager.shared.equalizer.setPreampDB(newPreamp)
        }
        
        // 限幅器只处理瞬态余量，不再替代前级补偿持续压扁动态。
        let shouldLimit = effectiveTuning.finalLimiterEnabled || peakGain > 0.1

        // AI 安全前级负责给完整处理链留余量，最终输出先补回这部分固定损失。
        // 蓝牙路线的有损编码会产生 inter-sample peak，补偿上限压到 +6 dB，
        // 留出真正的 ISP 余量而不是全部推给限幅器兜底。
        let makeupCeiling: Float = currentOutputKind == .bluetooth ? 6 : 9
        let aiOutputGainCompensation: Float = isAIManagedPresetActive
            ? min(makeupCeiling, max(0, -newPreamp))
            : 0
        // 宽频削减和动态处理仍可能让主观响度略低。额外补偿保持在约 1 dB，
        // 与固定前级补偿合计不超过 makeupCeiling，并在 AudioRepairEngine 内平滑推入。
        let perceivedCurveLoss = max(0, -perceivedBoost)
        let dynamicsMakeup: Float = isDynamicEQEnabled || isMultibandDynamicsEnabled
            ? 0.16
            : (effectiveTuning.compressorEnabled ? 0.12 : 0)
        let deviceMakeup: Float
        switch currentOutputKind {
        case .builtInSpeaker: deviceMakeup = 0.42
        case .bluetooth: deviceMakeup = 0.35
        case .car: deviceMakeup = 0.30
        case .wired, .airPlay, .usb, .other: deviceMakeup = 0.28
        }
        let requestedPerceptualMakeup = isAIManagedPresetActive
            ? min(1.05, deviceMakeup + min(0.5, perceivedCurveLoss * 0.38) + dynamicsMakeup)
            : 0
        let aiPerceptualMakeup = min(
            requestedPerceptualMakeup,
            max(0, makeupCeiling - aiOutputGainCompensation)
        )
        let routeSafeCeiling: Float = currentOutputKind == .bluetooth ? -1.5 : -1
        repair.configureOutputSafety(
            limiterEnabled: shouldLimit,
            ceilingDB: shouldLimit && effectiveTuning.finalLimiterEnabled
                ? min(effectiveTuning.finalLimiterCeilingDB, routeSafeCeiling)
                : routeSafeCeiling,
            transitionProtectionEnabled: false,
            outputGainDB: aiOutputGainCompensation,
            perceptualMakeupDB: aiPerceptualMakeup
        )
        isSafetyLimiterActive = shouldLimit
    }

    private static let tenBandLoudnessWeights: [Float] = [0.02, 0.055, 0.105, 0.145, 0.17, 0.17, 0.145, 0.105, 0.06, 0.025]

    private static func loudnessWeights(for mode: GraphicEQMode) -> [Float] {
        let resampled = mode.resampledGains(tenBandLoudnessWeights, from: .tenBand)
        let total = max(resampled.reduce(0, +), 0.000_001)
        return resampled.map { $0 / total }
    }

    /// 估算当前图示 EQ 级联后的实际最大正增益。首尾频段使用与
    /// Mono 实时处理相同的 shelf 形状，其余频段使用 peaking。
    /// 使用与 Mono EQFilter 相同的 RBJ 系数，在 20 Hz～近 Nyquist 之间按对数采样。
    private static func estimatedCurvePeakBoostDB(
        for gains: [Float],
        mode: GraphicEQMode,
        sampleRate: Float = 48_000
    ) -> Float {
        let frequencies = mode.centerFrequencies
        let qValues = mode.qValues
        guard !gains.isEmpty, gains.contains(where: { abs($0) > 0.001 }) else {
            return 0
        }

        let upperFrequency = min(20_000, sampleRate * 0.45)
        let ratio = upperFrequency / 20
        let sampleCount = 192
        var peakDB: Float = 0

        for point in 0 ..< sampleCount {
            let progress = Float(point) / Float(sampleCount - 1)
            let frequency = 20 * powf(ratio, progress)
            let omega = 2 * Float.pi * frequency / sampleRate
            var responseDB: Float = 0

            for index in frequencies.indices where index < gains.count {
                let gain = gains[index]
                guard abs(gain) > 0.001 else { continue }
                if mode == .tenBand, index == frequencies.startIndex {
                    responseDB += shelfResponseDB(gainDB: gain, frequency: frequencies[index], sampleRate: sampleRate, omega: omega, isHigh: false)
                } else if mode == .tenBand, index == frequencies.index(before: frequencies.endIndex) {
                    responseDB += shelfResponseDB(gainDB: gain, frequency: frequencies[index], sampleRate: sampleRate, omega: omega, isHigh: true)
                } else {
                    responseDB += peakingResponseDB(
                        gainDB: gain,
                        centerFrequency: frequencies[index],
                        q: qValues[index],
                        sampleRate: sampleRate,
                        omega: omega
                    )
                }
            }
            peakDB = max(peakDB, responseDB)
        }
        return max(0, peakDB)
    }

    private static func peakingResponseDB(
        gainDB: Float,
        centerFrequency: Float,
        q: Float,
        sampleRate: Float,
        omega: Float
    ) -> Float {
        let amplitude = powf(10, gainDB / 40)
        let centerOmega = 2 * Float.pi * centerFrequency / sampleRate
        let alpha = sinf(centerOmega) / (2 * q)
        let a0 = 1 + alpha / amplitude

        let b0 = (1 + alpha * amplitude) / a0
        let b1 = (-2 * cosf(centerOmega)) / a0
        let b2 = (1 - alpha * amplitude) / a0
        let a1 = (-2 * cosf(centerOmega)) / a0
        let a2 = (1 - alpha / amplitude) / a0

        return biquadResponseDB(b0: b0, b1: b1, b2: b2, a1: a1, a2: a2, omega: omega)
    }

    private static func shelfResponseDB(
        gainDB: Float,
        frequency: Float,
        sampleRate: Float,
        omega: Float,
        isHigh: Bool
    ) -> Float {
        let amplitude = powf(10, gainDB / 40)
        let centerOmega = 2 * Float.pi * min(frequency, sampleRate * 0.475) / sampleRate
        let cosine = cosf(centerOmega)
        let alpha = sinf(centerOmega) * sqrtf(2) / 2
        let beta = 2 * sqrtf(amplitude) * alpha
        let raw: (Float, Float, Float, Float, Float, Float)
        if isHigh {
            raw = (
                amplitude * ((amplitude + 1) + (amplitude - 1) * cosine + beta),
                -2 * amplitude * ((amplitude - 1) + (amplitude + 1) * cosine),
                amplitude * ((amplitude + 1) + (amplitude - 1) * cosine - beta),
                (amplitude + 1) - (amplitude - 1) * cosine + beta,
                2 * ((amplitude - 1) - (amplitude + 1) * cosine),
                (amplitude + 1) - (amplitude - 1) * cosine - beta
            )
        } else {
            raw = (
                amplitude * ((amplitude + 1) - (amplitude - 1) * cosine + beta),
                2 * amplitude * ((amplitude - 1) - (amplitude + 1) * cosine),
                amplitude * ((amplitude + 1) - (amplitude - 1) * cosine - beta),
                (amplitude + 1) + (amplitude - 1) * cosine + beta,
                -2 * ((amplitude - 1) + (amplitude + 1) * cosine),
                (amplitude + 1) + (amplitude - 1) * cosine - beta
            )
        }
        let a0 = abs(raw.3) < 0.000_001 ? 1 : raw.3
        return biquadResponseDB(
            b0: raw.0 / a0,
            b1: raw.1 / a0,
            b2: raw.2 / a0,
            a1: raw.4 / a0,
            a2: raw.5 / a0,
            omega: omega
        )
    }

    private static func estimatedParametricPeakBoostDB(
        for bands: [ParametricEQBand],
        sampleRate: Float = 48_000
    ) -> Float {
        // Pass and notch filters never add headroom. For boosts, the sum of
        // positive gains is conservative and stable while users drag Q/Fc.
        return bands.reduce(Float(0)) { result, band in
            guard band.isEnabled else { return result }
            switch band.type {
            case .peak, .lowShelf, .highShelf:
                return result + max(band.gainDB, 0)
            case .lowPass, .highPass, .notch:
                return result
            }
        }
    }

    private static func biquadResponseDB(
        b0: Float, b1: Float, b2: Float, a1: Float, a2: Float, omega: Float
    ) -> Float {
        let cos1 = cosf(omega)
        let sin1 = sinf(omega)
        let cos2 = cosf(2 * omega)
        let sin2 = sinf(2 * omega)
        let numeratorReal = b0 + b1 * cos1 + b2 * cos2
        let numeratorImaginary = -(b1 * sin1 + b2 * sin2)
        let denominatorReal = 1 + a1 * cos1 + a2 * cos2
        let denominatorImaginary = -(a1 * sin1 + a2 * sin2)
        let numeratorPower = numeratorReal * numeratorReal + numeratorImaginary * numeratorImaginary
        let denominatorPower = max(
            denominatorReal * denominatorReal + denominatorImaginary * denominatorImaginary,
            0.000_000_1
        )
        return 10 * log10f(max(numeratorPower / denominatorPower, 0.000_000_1))
    }
    
    private func disableSafetyMeasures() {
        let player = PlayerManager.shared
        if preampDB != 0 {
            preampDB = 0
            player.equalizer.setPreampDB(0)
        }
        if isSafetyLimiterActive {
            player.audioRepair.configureOutputSafety(
                limiterEnabled: false,
                transitionProtectionEnabled: false
            )
            isSafetyLimiterActive = false
        } else {
            player.audioRepair.configureOutputSafety(
                limiterEnabled: false,
                transitionProtectionEnabled: false
            )
        }
        player.audioEffects.setLimiterEnabled(false)
    }
    
    // MARK: - 自定义预设管理
    
    func saveCustomPreset(name: String, description: String = "") {
        let preset = EQPreset(
            id: "custom_\(UUID().uuidString.prefix(8))",
            name: name,
            category: .custom,
            description: description,
            gains: customGains,
            isCustom: true,
            presetType: graphicEQMode == .tenBand ? .standard10 : .graphic32,
            preampDB: customPresetPreampDB
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

    func makeCloudCustomPresets() -> [EQPreset]? {
        customPresets.isEmpty ? nil : customPresets
    }

    func restoreCloudCustomPresets(_ remotePresets: [EQPreset]) {
        let validRemote = remotePresets.filter { preset in
            preset.isCustom
                && preset.presetType.expectedGainCount == preset.gains.count
                && preset.gains.allSatisfy(\.isFinite)
        }
        guard !validRemote.isEmpty else { return }

        var merged = Dictionary(uniqueKeysWithValues: customPresets.map { ($0.id, $0) })
        for preset in validRemote {
            merged[preset.id] = preset
        }
        customPresets = merged.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        saveState()
    }
    
    // MARK: - 持久化
    
    private struct EQState: Codable {
        let isEnabled: Bool
        let currentPresetId: String?
        let transientPreset: EQPreset?
        let customGains: [Float]
        let customPresets: [EQPreset]
        let graphicEQMode: GraphicEQMode?
        let tenBandCustomGains: [Float]?
        let thirtyTwoBandCustomGains: [Float]?
    }
    
    /// 音效旋钮状态（独立于 EQ）
    private struct AudioEffectsState: Codable {
        let bassGain: Float
        let trebleGain: Float
        let surroundLevel: Float
        let reverbLevel: Float
        let stereoWidth: Float?
    }

    private struct ProfessionalState: Codable {
        /// 可选字段用于兼容没有处理强度的旧版专业模式状态。
        let professionalProcessingIntensity: Float?
        let isLoudnessMatchingEnabled: Bool
        let isOutputCalibrationEnabled: Bool
        let isSmartSongCompensationEnabled: Bool
        let isDynamicEQEnabled: Bool
        let isMultibandDynamicsEnabled: Bool
        let isParametricEQEnabled: Bool
        let parametricBands: [ParametricEQBand]
        let dynamicEQBands: [DynamicEQBand]
        let multibandConfiguration: MultibandDynamicsConfiguration
        let monoEffectTuning: MonoEffectTuningConfiguration?
        let customPresetPreampDB: Float
        let selectedHeadphoneProfileID: String
        let headphoneProfiles: [MonoHeadphoneCorrectionProfile]
        let presetPreampOverrides: [String: Float]
    }

    private struct AIProcessingSnapshot: Codable {
        let isEnabled: Bool
        let currentPreset: EQPreset?
        let customGains: [Float]
        let graphicEQMode: GraphicEQMode?
        let tenBandCustomGains: [Float]?
        let thirtyTwoBandCustomGains: [Float]?
        let customPresetPreampDB: Float
        let professionalProcessingIntensity: Float
        let isLoudnessMatchingEnabled: Bool
        let isOutputCalibrationEnabled: Bool
        let isSmartSongCompensationEnabled: Bool
        let isDynamicEQEnabled: Bool
        let dynamicEQBands: [DynamicEQBand]
        let isMultibandDynamicsEnabled: Bool
        let multibandConfiguration: MultibandDynamicsConfiguration
        let isParametricEQEnabled: Bool
        let parametricBands: [ParametricEQBand]
        let monoEffectTuning: MonoEffectTuningConfiguration?
        let bassGain: Float
        let trebleGain: Float
        let surroundLevel: Float
        let reverbLevel: Float
        let stereoWidth: Float
    }
    
    private static let eqStateKey = "monologue_eq_state_v5"
    private static let audioEffectsStateKey = "monologue_audio_effects_state"
    private static let professionalStateKey = "monologue_eq_professional_state_v1"
    private static let aiProcessingSnapshotKey = "monologue_eq_ai_processing_snapshot_v1"

    private func captureProcessingBeforeAIIfNeeded() {
        guard preAIProcessingSnapshot == nil, !isAIManagedPresetActive else { return }
        let effects = PlayerManager.shared.audioEffects
        let snapshot = AIProcessingSnapshot(
            isEnabled: isEnabled,
            currentPreset: currentPreset,
            customGains: customGains,
            graphicEQMode: graphicEQMode,
            tenBandCustomGains: tenBandCustomGains,
            thirtyTwoBandCustomGains: thirtyTwoBandCustomGains,
            customPresetPreampDB: customPresetPreampDB,
            professionalProcessingIntensity: professionalProcessingIntensity,
            isLoudnessMatchingEnabled: isLoudnessMatchingEnabled,
            isOutputCalibrationEnabled: isOutputCalibrationEnabled,
            isSmartSongCompensationEnabled: isSmartSongCompensationEnabled,
            isDynamicEQEnabled: isDynamicEQEnabled,
            dynamicEQBands: dynamicEQBands,
            isMultibandDynamicsEnabled: isMultibandDynamicsEnabled,
            multibandConfiguration: multibandConfiguration,
            isParametricEQEnabled: isParametricEQEnabled,
            parametricBands: parametricBands,
            monoEffectTuning: monoEffectTuning,
            bassGain: effects.bassGain,
            trebleGain: effects.trebleGain,
            surroundLevel: effects.surroundLevel,
            reverbLevel: effects.reverbLevel,
            stereoWidth: effects.stereoWidth
        )
        preAIProcessingSnapshot = snapshot
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.aiProcessingSnapshotKey)
        }
    }

    private func restoreAIProcessingSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: Self.aiProcessingSnapshotKey),
              let snapshot = try? JSONDecoder().decode(AIProcessingSnapshot.self, from: data) else {
            return
        }
        preAIProcessingSnapshot = snapshot
    }

    private func neutralAIProcessingSnapshot() -> AIProcessingSnapshot {
        AIProcessingSnapshot(
            isEnabled: true,
            currentPreset: builtInPreset(familyID: "flat", mode: .tenBand),
            customGains: Array(repeating: 0, count: 10),
            graphicEQMode: .tenBand,
            tenBandCustomGains: Array(repeating: 0, count: GraphicEQMode.tenBand.bandCount),
            thirtyTwoBandCustomGains: Array(repeating: 0, count: GraphicEQMode.thirtyTwoBand.bandCount),
            customPresetPreampDB: 0,
            professionalProcessingIntensity: 1,
            isLoudnessMatchingEnabled: false,
            isOutputCalibrationEnabled: false,
            isSmartSongCompensationEnabled: false,
            isDynamicEQEnabled: false,
            dynamicEQBands: DynamicEQBand.monoDefaults,
            isMultibandDynamicsEnabled: false,
            multibandConfiguration: MultibandDynamicsConfiguration(isEnabled: false),
            isParametricEQEnabled: false,
            parametricBands: [],
            monoEffectTuning: .neutral,
            bassGain: 0,
            trebleGain: 0,
            surroundLevel: 0,
            reverbLevel: 0,
            stereoWidth: 1
        )
    }
    
    private func saveState() {
        let isTransientPreset = currentPreset?.id == "custom"
            || currentPreset?.id.hasPrefix("ai_") == true
        let state = EQState(
            isEnabled: isEnabled,
            currentPresetId: currentPreset?.id,
            transientPreset: isTransientPreset ? currentPreset : nil,
            customGains: customGains,
            customPresets: customPresets,
            graphicEQMode: graphicEQMode,
            tenBandCustomGains: tenBandCustomGains,
            thirtyTwoBandCustomGains: thirtyTwoBandCustomGains
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.eqStateKey)
        }
    }

    private func saveProfessionalState() {
        guard !isRestoring else { return }
        let state = ProfessionalState(
            professionalProcessingIntensity: professionalProcessingIntensity,
            isLoudnessMatchingEnabled: isLoudnessMatchingEnabled,
            isOutputCalibrationEnabled: isOutputCalibrationEnabled,
            isSmartSongCompensationEnabled: isSmartSongCompensationEnabled,
            isDynamicEQEnabled: isDynamicEQEnabled,
            isMultibandDynamicsEnabled: isMultibandDynamicsEnabled,
            isParametricEQEnabled: isParametricEQEnabled,
            parametricBands: parametricBands,
            dynamicEQBands: dynamicEQBands,
            multibandConfiguration: multibandConfiguration,
            monoEffectTuning: monoEffectTuning,
            customPresetPreampDB: customPresetPreampDB,
            selectedHeadphoneProfileID: selectedHeadphoneProfileID,
            headphoneProfiles: headphoneProfiles,
            presetPreampOverrides: presetPreampOverrides
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.professionalStateKey)
        }
    }

    private func restoreProfessionalState() {
        guard let data = UserDefaults.standard.data(forKey: Self.professionalStateKey),
              let state = try? JSONDecoder().decode(ProfessionalState.self, from: data)
        else { return }
        professionalProcessingIntensity = Self.clampedProfessionalIntensity(
            state.professionalProcessingIntensity ?? 1.3
        )
        isLoudnessMatchingEnabled = state.isLoudnessMatchingEnabled
        isOutputCalibrationEnabled = state.isOutputCalibrationEnabled
        isSmartSongCompensationEnabled = state.isSmartSongCompensationEnabled
        isDynamicEQEnabled = state.isDynamicEQEnabled
        isMultibandDynamicsEnabled = state.isMultibandDynamicsEnabled
        isParametricEQEnabled = state.isParametricEQEnabled
        parametricBands = state.parametricBands
        dynamicEQBands = state.dynamicEQBands
        multibandConfiguration = state.multibandConfiguration
        monoEffectTuning = state.monoEffectTuning ?? .neutral
        customPresetPreampDB = Self.clampedPreamp(state.customPresetPreampDB)
        selectedHeadphoneProfileID = state.selectedHeadphoneProfileID
        headphoneProfiles = state.headphoneProfiles
        presetPreampOverrides = state.presetPreampOverrides
    }
    
    /// 保存音效旋钮状态（低音/高音/环绕/混响，独立于 EQ）
    func saveAudioEffectsState() {
        let effects = PlayerManager.shared.audioEffects
        let state = AudioEffectsState(
            bassGain: effects.bassGain,
            trebleGain: effects.trebleGain,
            surroundLevel: effects.surroundLevel,
            reverbLevel: effects.reverbLevel,
            stereoWidth: effects.stereoWidth
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.audioEffectsStateKey)
        }
    }
    
    private func restoreAudioEffectsState() {
        guard let data = UserDefaults.standard.data(forKey: Self.audioEffectsStateKey),
              let state = try? JSONDecoder().decode(AudioEffectsState.self, from: data) else {
            // 兼容：尝试从旧的缓存系统迁移
            if let state = OptimizedCacheManager.shared.getObject(forKey: "audio_effects_state", type: AudioEffectsState.self) {
                let effects = PlayerManager.shared.audioEffects
                effects.applyMonoTuning(
                    monoEffectTuning,
                    bassGain: state.bassGain,
                    trebleGain: state.trebleGain,
                    surroundLevel: state.surroundLevel,
                    reverbLevel: state.reverbLevel,
                    stereoWidth: state.stereoWidth ?? 1
                )
                saveAudioEffectsState()
            }
            return
        }
        let effects = PlayerManager.shared.audioEffects
        effects.applyMonoTuning(
            monoEffectTuning,
            bassGain: state.bassGain,
            trebleGain: state.trebleGain,
            surroundLevel: state.surroundLevel,
            reverbLevel: state.reverbLevel,
            stereoWidth: state.stereoWidth ?? 1
        )
    }
    
    private func restoreState() {
        restoreAudioEffectsState()
        
        // v5: 从 UserDefaults 恢复
        if let data = UserDefaults.standard.data(forKey: Self.eqStateKey),
           let state = try? JSONDecoder().decode(EQState.self, from: data) {
            self.customPresets = state.customPresets
            let restoredMode = state.graphicEQMode
                ?? (state.customGains.count == GraphicEQMode.thirtyTwoBand.bandCount ? .thirtyTwoBand : .tenBand)
            self.graphicEQMode = restoredMode
            self.tenBandCustomGains = GraphicEQMode.tenBand.normalizedGains(
                state.tenBandCustomGains ?? (restoredMode == .tenBand ? state.customGains : [])
            )
            self.thirtyTwoBandCustomGains = GraphicEQMode.thirtyTwoBand.normalizedGains(
                state.thirtyTwoBandCustomGains ?? (restoredMode == .thirtyTwoBand ? state.customGains : [])
            )
            self.customGains = restoredMode == .tenBand ? tenBandCustomGains : thirtyTwoBandCustomGains
            self.isEnabled = state.isEnabled
            if let presetId = state.currentPresetId {
                self.currentPreset = allPresets.first { $0.id == presetId }
                    ?? (state.transientPreset?.id == presetId ? state.transientPreset : nil)
            }
            self.currentPreset = matchingBuiltInPreset(currentPreset, mode: restoredMode)
            if isEnabled {
                if let preset = currentPreset {
                    applyPresetCurve(preset)
                } else {
                    applyCustomGains()
                }
            } else {
                PlayerManager.shared.equalizer.setGraphicMode(graphicEQMode, gainsDB: customGains)
            }
            updateSafetyLimiter()
            return
        }
        
        // 兼容：从旧的缓存系统迁移（v4 及更早版本）
        if let state = OptimizedCacheManager.shared.getObject(forKey: "eq_state_v4", type: EQState.self) {
            self.customPresets = state.customPresets
            let restoredMode = state.graphicEQMode
                ?? (state.customGains.count == GraphicEQMode.thirtyTwoBand.bandCount ? .thirtyTwoBand : .tenBand)
            self.graphicEQMode = restoredMode
            self.tenBandCustomGains = GraphicEQMode.tenBand.normalizedGains(
                state.tenBandCustomGains ?? (restoredMode == .tenBand ? state.customGains : [])
            )
            self.thirtyTwoBandCustomGains = GraphicEQMode.thirtyTwoBand.normalizedGains(
                state.thirtyTwoBandCustomGains ?? (restoredMode == .thirtyTwoBand ? state.customGains : [])
            )
            self.customGains = restoredMode == .tenBand ? tenBandCustomGains : thirtyTwoBandCustomGains
            self.isEnabled = state.isEnabled
            if let presetId = state.currentPresetId {
                self.currentPreset = allPresets.first { $0.id == presetId }
                    ?? (state.transientPreset?.id == presetId ? state.transientPreset : nil)
            }
            self.currentPreset = matchingBuiltInPreset(currentPreset, mode: restoredMode)
            if isEnabled {
                if let preset = currentPreset {
                    applyPresetCurve(preset)
                } else {
                    applyCustomGains()
                }
            } else {
                PlayerManager.shared.equalizer.setGraphicMode(graphicEQMode, gainsDB: customGains)
            }
            updateSafetyLimiter()
            saveState()
            return
        }
        
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
                self.graphicEQMode = .tenBand
                self.tenBandCustomGains = GraphicEQMode.tenBand.normalizedGains(state.customGains)
                self.thirtyTwoBandCustomGains = Array(repeating: 0, count: GraphicEQMode.thirtyTwoBand.bandCount)
                self.customGains = tenBandCustomGains
                self.isEnabled = state.isEnabled
                if let presetId = state.currentPresetId {
                    self.currentPreset = allPresets.first { $0.id == presetId }
                }
                if isEnabled, let preset = currentPreset {
                    applyPresetCurve(preset)
                }
                updateSafetyLimiter()
                saveState()
                return
            }
        }
    }
}
