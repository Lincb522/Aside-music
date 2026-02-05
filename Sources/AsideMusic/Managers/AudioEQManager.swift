//
//  AudioEQManager.swift
//  AsideMusic
//
//  流媒体实时均衡器管理器
//  使用 MTAudioProcessingTap 对 AVPlayer 音频流进行实时处理
//

import AVFoundation
import Accelerate

// MARK: - Custom EQ Preset Model

struct CustomEQPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var bands: [Float]
    var createdAt: Date
    
    init(name: String, bands: [Float]) {
        self.id = UUID()
        self.name = name
        self.bands = bands
        self.createdAt = Date()
    }
}

// MARK: - EQ Preset

/// EQ 预设
enum EQPreset: String, CaseIterable, Identifiable {
    // 基础预设
    case flat = "平坦"
    case bass = "低音增强"
    case treble = "高音增强"
    case vocal = "人声增强"
    
    // 音乐风格
    case rock = "摇滚"
    case pop = "流行"
    case jazz = "爵士"
    case classical = "古典"
    case electronic = "电子"
    case hiphop = "嘻哈"
    case rnb = "R&B"
    case metal = "金属"
    case acoustic = "原声"
    case piano = "钢琴"

    // 场景预设
    case lateNight = "深夜模式"
    case smallSpeaker = "小音箱"
    case headphone = "耳机优化"
    case carAudio = "车载音响"
    case loudness = "响度增强"
    
    // 空间音效预设
    case spatial3D = "3D环绕"
    case wideStage = "宽广舞台"
    case intimate = "亲密空间"
    
    // 自定义
    case custom = "自定义"
    
    var id: String { rawValue }
    
    /// 预设的增益值 (10段: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz)
    var gains: [Float] {
        switch self {
        // 基础
        case .flat:       return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bass:       return [8, 6, 4, 2, 0, 0, 0, 0, 0, 0]
        case .treble:     return [0, 0, 0, 0, 0, 0, 2, 4, 6, 8]
        case .vocal:      return [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]
        
        // 音乐风格
        case .rock:       return [5, 4, 2, 0, -1, 0, 2, 4, 5, 5]
        case .pop:        return [2, 3, 4, 2, 0, 0, 1, 2, 3, 2]
        case .jazz:       return [4, 3, 1, 2, -1, -1, 0, 2, 3, 4]
        case .classical:  return [4, 3, 2, 1, 0, 0, 0, 1, 2, 3]
        case .electronic: return [6, 5, 3, 0, -2, -1, 0, 3, 5, 6]
        case .hiphop:     return [6, 5, 3, 1, 0, 0, 1, 2, 2, 3]
        case .rnb:        return [4, 6, 4, 1, -1, 0, 2, 3, 3, 2]
        case .metal:      return [6, 4, 0, -2, -3, -2, 0, 4, 6, 5]
        case .acoustic:   return [3, 2, 1, 1, 0, 0, 1, 2, 3, 3]
        case .piano:      return [2, 1, 0, 1, 2, 2, 1, 2, 3, 2]

        // 场景
        case .lateNight:   return [-2, -1, 0, 1, 2, 2, 1, 0, -1, -2]
        case .smallSpeaker: return [6, 5, 3, 1, 0, 0, 1, 2, 3, 4]
        case .headphone:   return [3, 2, 0, -1, 0, 0, -1, 0, 2, 3]
        case .carAudio:    return [4, 3, 1, 0, 0, 0, 1, 2, 3, 4]
        case .loudness:    return [5, 4, 2, 0, -2, -2, 0, 2, 4, 5]
        
        // 空间音效
        case .spatial3D:   return [2, 1, 0, -1, -1, -1, 0, 1, 2, 3]
        case .wideStage:   return [3, 2, 0, -1, -2, -2, -1, 0, 2, 4]
        case .intimate:    return [1, 2, 3, 2, 1, 1, 2, 2, 1, 0]
        
        case .custom:      return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        }
    }
    
    /// 预设分类
    var category: String {
        switch self {
        case .flat, .bass, .treble, .vocal:
            return "基础"
        case .rock, .pop, .jazz, .classical, .electronic, .hiphop, .rnb, .metal, .acoustic, .piano:
            return "音乐风格"
        case .lateNight, .smallSpeaker, .headphone, .carAudio, .loudness:
            return "场景"
        case .spatial3D, .wideStage, .intimate:
            return "空间音效"
        case .custom:
            return "自定义"
        }
    }
    
    /// 按分类分组
    static var grouped: [(category: String, presets: [EQPreset])] {
        let categories = ["基础", "音乐风格", "场景", "空间音效"]
        return categories.map { cat in
            (cat, allCases.filter { $0.category == cat && $0 != .custom })
        }
    }
}


// MARK: - Audio EQ Manager

/// 均衡器管理器
@MainActor
final class AudioEQManager: ObservableObject {
    static let shared = AudioEQManager()
    
    // MARK: - Published Properties
    
    /// EQ 是否启用
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "eq_enabled")
            processor?.setEnabled(isEnabled)
        }
    }
    
    /// 当前预设
    @Published var currentPreset: EQPreset = .flat {
        didSet {
            if currentPreset != .custom {
                bands = currentPreset.gains
            }
            UserDefaults.standard.set(currentPreset.rawValue, forKey: "eq_preset")
        }
    }
    
    /// 当前自定义预设 ID (如果选中的是自定义预设)
    @Published var currentCustomPresetId: UUID? = nil
    
    /// 10 段 EQ 增益 (-12 到 +12 dB)
    @Published var bands: [Float] = Array(repeating: 0, count: 10) {
        didSet {
            nonisolated(unsafe) let newBands = bands
            Task.detached { [weak self] in
                await self?.updateProcessorBands(newBands)
            }
            if let data = try? JSONEncoder().encode(bands) {
                UserDefaults.standard.set(data, forKey: "eq_custom_bands")
            }
        }
    }
    
    /// 用户保存的自定义预设
    @Published var customPresets: [CustomEQPreset] = []
    
    // MARK: - Constants
    
    static let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    static let frequencyLabels: [String] = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    static let maxCustomPresets = 10
    
    // MARK: - Internal
    
    nonisolated(unsafe) var processor: AudioEQProcessor?

    
    // MARK: - Init
    
    private init() {
        loadCustomPresets()
        
        isEnabled = UserDefaults.standard.bool(forKey: "eq_enabled")
        smartModeEnabled = UserDefaults.standard.bool(forKey: "eq_smart_mode")
        
        if let noiseRaw = UserDefaults.standard.string(forKey: "eq_noise_reduction"),
           let noiseMode = NoiseReductionMode(rawValue: noiseRaw) {
            noiseReductionMode = noiseMode
        }
        
        if let presetRaw = UserDefaults.standard.string(forKey: "eq_preset"),
           let preset = EQPreset(rawValue: presetRaw) {
            currentPreset = preset
        }
        
        if let data = UserDefaults.standard.data(forKey: "eq_custom_bands"),
           let savedBands = try? JSONDecoder().decode([Float].self, from: data),
           savedBands.count == 10 {
            bands = savedBands
        } else {
            bands = currentPreset.gains
        }
        
        processor = AudioEQProcessor(bands: bands)
        processor?.setSmartMode(smartModeEnabled)
        processor?.setNoiseReduction(noiseReductionMode)
    }
    
    // MARK: - Public Methods
    
    /// 为 AVPlayerItem 添加 EQ 处理
    nonisolated func attachEQ(to playerItem: AVPlayerItem) {
        guard let processor = processor else { return }
        processor.attach(to: playerItem)
    }
    
    /// 设置单个频段增益
    func setBand(_ index: Int, gain: Float) {
        guard index >= 0 && index < 10 else { return }
        let clampedGain = max(-12, min(12, gain))
        bands[index] = clampedGain
        currentPreset = .custom
        currentCustomPresetId = nil
        smartModeEnabled = false
    }
    
    /// 重置为平坦
    func reset() {
        currentPreset = .flat
        currentCustomPresetId = nil
        smartModeEnabled = false
    }
    
    /// 应用预设
    func applyPreset(_ preset: EQPreset) {
        currentPreset = preset
        currentCustomPresetId = nil
        smartModeEnabled = false
    }
    
    /// 应用自定义预设
    func applyCustomPreset(_ preset: CustomEQPreset) {
        bands = preset.bands
        currentPreset = .custom
        currentCustomPresetId = preset.id
        smartModeEnabled = false
    }
    
    // MARK: - Smart Mode
    
    /// 智能模式是否启用
    @Published var smartModeEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(smartModeEnabled, forKey: "eq_smart_mode")
            processor?.setSmartMode(smartModeEnabled)
            
            if smartModeEnabled {
                currentPreset = .custom
                currentCustomPresetId = nil
            }
        }
    }
    
    /// 当前检测到的音乐类型
    @Published var detectedGenre: DetectedGenre = .unknown
    
    /// 降噪模式
    @Published var noiseReductionMode: NoiseReductionMode = .off {
        didSet {
            UserDefaults.standard.set(noiseReductionMode.rawValue, forKey: "eq_noise_reduction")
            processor?.setNoiseReduction(noiseReductionMode)
        }
    }
    
    /// 智能模式自动应用 EQ (由处理器调用)
    func applySmartEQ(_ eq: [Float], genre: DetectedGenre) {
        guard smartModeEnabled else { return }
        
        // 平滑过渡到新 EQ
        for i in 0..<min(eq.count, bands.count) {
            bands[i] = bands[i] * 0.7 + eq[i] * 0.3
        }
        
        detectedGenre = genre
    }
    
    /// 获取当前分析结果
    var analysisResult: AudioAnalysisResult? {
        processor?.analysisResult
    }
    
    /// 应用推荐的 EQ
    func applyRecommendedEQ() {
        guard let recommended = processor?.recommendedEQ else { return }
        bands = recommended
        currentPreset = .custom
        currentCustomPresetId = nil
    }

    
    // MARK: - Custom Preset Management
    
    /// 保存当前设置为自定义预设
    func saveCurrentAsPreset(name: String) -> Bool {
        guard customPresets.count < Self.maxCustomPresets else { return false }
        guard !name.isEmpty else { return false }
        
        let preset = CustomEQPreset(name: name, bands: bands)
        customPresets.append(preset)
        saveCustomPresets()
        
        currentCustomPresetId = preset.id
        return true
    }
    
    /// 更新自定义预设
    func updateCustomPreset(_ id: UUID, name: String? = nil, bands: [Float]? = nil) {
        guard let index = customPresets.firstIndex(where: { $0.id == id }) else { return }
        
        if let name = name {
            customPresets[index].name = name
        }
        if let bands = bands {
            customPresets[index].bands = bands
        }
        saveCustomPresets()
    }
    
    /// 删除自定义预设
    func deleteCustomPreset(_ id: UUID) {
        customPresets.removeAll { $0.id == id }
        saveCustomPresets()
        
        if currentCustomPresetId == id {
            currentCustomPresetId = nil
        }
    }
    
    /// 覆盖保存当前设置到已有预设
    func overwritePreset(_ id: UUID) {
        guard let index = customPresets.firstIndex(where: { $0.id == id }) else { return }
        customPresets[index].bands = bands
        saveCustomPresets()
    }
    
    // MARK: - Private
    
    private func updateProcessorBands(_ newBands: [Float]) async {
        processor?.updateBands(newBands)
    }
    
    private func loadCustomPresets() {
        if let data = UserDefaults.standard.data(forKey: "eq_custom_presets"),
           let presets = try? JSONDecoder().decode([CustomEQPreset].self, from: data) {
            customPresets = presets
        }
    }
    
    private func saveCustomPresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: "eq_custom_presets")
        }
    }
}
