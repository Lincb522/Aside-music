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
    
    // MARK: - Published
    
    @Published var isEnabled: Bool = false {
        didSet {
            if !isEnabled {
                PlayerManager.shared.equalizer.reset()
            } else {
                if let preset = currentPreset {
                    preset.apply(to: PlayerManager.shared.equalizer)
                }
            }
            saveState()
        }
    }
    
    @Published var currentPreset: EQPreset? = nil {
        didSet {
            if isEnabled, let preset = currentPreset {
                preset.apply(to: PlayerManager.shared.equalizer)
            }
            saveState()
        }
    }
    
    @Published var customGains: [Float] = Array(repeating: 0, count: 10) {
        didSet {
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
    
    let builtInPresets: [EQPreset] = [
        // ═══════════════════════════════════════
        // 默认
        // ═══════════════════════════════════════
        EQPreset(
            id: "flat",
            name: "平坦",
            category: .flat,
            description: "无修饰的原始音频",
            gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        ),
        
        // ═══════════════════════════════════════
        // 音乐风格预设
        // ═══════════════════════════════════════
        
        // 流行：经典 V 型曲线，低频冲击 + 高频亮度，中频凹陷让人声不刺耳
        EQPreset(
            id: "pop",
            name: "流行",
            category: .genre,
            description: "增强低频和高频，适合流行音乐",
            gains: [2.5, 4.5, 5.5, 2.0, -2.0, -2.5, 1.5, 4.5, 6.0, 4.5]
        ),
        
        // 摇滚：中低频饱满有力，高频明亮，吉他 riff 突出
        EQPreset(
            id: "rock",
            name: "摇滚",
            category: .genre,
            description: "强劲的中低频和明亮的高频",
            gains: [5.0, 5.5, 3.5, 1.0, -1.5, 1.0, 3.5, 5.5, 5.0, 3.0]
        ),
        
        // 嘻哈：深沉 808 低音 + 清晰人声
        EQPreset(
            id: "hiphop",
            name: "嘻哈",
            category: .genre,
            description: "深沉低音和清晰人声",
            gains: [7.5, 7.0, 4.5, 1.0, -1.0, 1.0, 2.5, 3.0, 1.5, 0.5]
        ),
        
        // 电子/EDM：极强低频 + 合成器高频，中频让路
        EQPreset(
            id: "electronic",
            name: "电子",
            category: .genre,
            description: "强劲低频和明亮合成器音色",
            gains: [7.0, 6.5, 4.0, 0.5, -2.5, -1.0, 2.0, 5.0, 5.5, 5.0]
        ),
        
        // 古典：自然平衡，轻微提升高频空气感，保持中频透明
        EQPreset(
            id: "classical",
            name: "古典",
            category: .genre,
            description: "自然平衡，保留乐器细节",
            gains: [0.5, 0.5, -0.5, -0.5, 0, 0, 1.0, 2.0, 3.0, 3.5]
        ),
        
        // 爵士：温暖中低频，铜管乐器临场感
        EQPreset(
            id: "jazz",
            name: "爵士",
            category: .genre,
            description: "温暖饱满的中低频音色",
            gains: [2.0, 3.5, 4.0, 3.0, 1.0, 0, 1.5, 2.5, 3.0, 2.5]
        ),
        
        // R&B/Soul：温暖低频包裹 + 丝滑人声
        EQPreset(
            id: "rnb",
            name: "R&B",
            category: .genre,
            description: "丝滑温暖的人声和低频",
            gains: [5.0, 5.5, 4.0, 1.5, 0, 1.5, 3.0, 2.5, 1.0, 0]
        ),
        
        // 金属：极端 Scooped 音色，低频和高频猛烈冲击
        EQPreset(
            id: "metal",
            name: "金属",
            category: .genre,
            description: "极端的低频和高频冲击",
            gains: [6.0, 5.0, 0.5, -3.5, -5.0, -3.5, 0.5, 5.0, 7.0, 6.0]
        ),
        
        // 民谣/原声：木吉他 body + presence 突出
        EQPreset(
            id: "acoustic",
            name: "民谣",
            category: .genre,
            description: "突出原声乐器的自然音色",
            gains: [1.0, 2.0, 3.5, 4.0, 2.5, 1.0, 2.5, 4.0, 3.5, 2.0]
        ),
        
        // 华语：中文人声频段精细优化，减少浑浊
        EQPreset(
            id: "chinese",
            name: "华语",
            category: .genre,
            description: "针对中文人声优化",
            gains: [1.5, 2.0, 1.5, -1.0, -2.0, 2.5, 4.5, 4.0, 2.5, 1.0]
        ),
        
        // 日系/J-Pop：明亮通透，高频空气感极强
        EQPreset(
            id: "jpop",
            name: "日系",
            category: .genre,
            description: "明亮通透的日系音色",
            gains: [1.0, 1.5, 1.0, 0, -1.0, 1.0, 3.0, 5.0, 6.0, 5.5]
        ),
        
        // ═══════════════════════════════════════
        // 环绕音效预设
        // ═══════════════════════════════════════
        // 环绕音效通过 EQ 曲线模拟空间感：
        // - 提升高频 (8-16kHz) 增加空气感和空间延展
        // - 轻微凹陷中频 (500Hz-2kHz) 制造距离感
        // - 低频控制影响空间大小感知
        // - 参考 Dolby Atmos Music、Sony 360 Reality Audio 的频响特征
        
        // 3D 环绕：低频体感 + 中频深凹制造距离 + 高频空气感
        EQPreset(
            id: "surround_3d",
            name: "3D 环绕",
            category: .surround,
            description: "全方位 3D 空间感，模拟 Dolby Atmos 频响",
            gains: [4.5, 3.5, 1.5, -2.5, -4.0, -3.5, 1.0, 5.0, 7.0, 6.5]
        ),
        
        // 影院环绕：强劲低音炮 + 大空间混响衰减 + 反射声
        EQPreset(
            id: "surround_cinema",
            name: "影院环绕",
            category: .surround,
            description: "模拟 THX 影院音响系统的包围感",
            gains: [7.0, 6.5, 4.0, -1.0, -3.5, -2.5, 1.5, 4.5, 5.5, 4.5]
        ),
        
        // 音乐厅：温暖低频 + 自然衰减 + 柔和空气感
        EQPreset(
            id: "surround_concert_hall",
            name: "音乐厅",
            category: .surround,
            description: "模拟古典音乐厅的自然混响空间",
            gains: [2.5, 3.0, 2.5, 0.5, -1.5, -1.0, 1.0, 2.5, 4.0, 4.5]
        ),
        
        // 体育场：开阔声场，中频距离衰减
        EQPreset(
            id: "surround_stadium",
            name: "体育场",
            category: .surround,
            description: "大型露天场馆的开阔声场",
            gains: [-1.5, 1.0, 2.5, -1.0, -3.5, -2.5, 1.5, 5.0, 3.0, 1.0]
        ),
        
        // 教堂：石墙低频共鸣 + 长混响 + 空间延展
        EQPreset(
            id: "surround_church",
            name: "教堂",
            category: .surround,
            description: "大教堂的庄严长混响空间",
            gains: [5.0, 4.5, 3.0, 1.0, -2.5, -3.5, -1.0, 2.5, 4.5, 5.0]
        ),
        
        // 录音棚：精确监听，轻微高频提升
        EQPreset(
            id: "surround_studio",
            name: "录音棚",
            category: .surround,
            description: "专业录音棚的精确监听空间",
            gains: [1.0, 1.0, 0, 0, -1.0, 0, 1.0, 2.0, 2.5, 2.0]
        ),
        
        // 宽声场：中频深凹 + 两端大幅提升
        EQPreset(
            id: "surround_wide",
            name: "宽声场",
            category: .surround,
            description: "最大化立体声宽度和分离度",
            gains: [4.0, 3.0, 1.0, -2.5, -5.0, -4.0, 0.5, 4.0, 6.0, 5.5]
        ),
        
        // 环绕低音：极强低频包围 + 空间感
        EQPreset(
            id: "surround_bass",
            name: "环绕低音",
            category: .surround,
            description: "低频包围感 + 空间环绕",
            gains: [8.5, 8.0, 5.5, 1.0, -3.0, -2.5, 0.5, 3.0, 4.5, 3.5]
        ),
        
        // 虚拟 5.1：声道分离 + 环绕声道模拟
        EQPreset(
            id: "surround_51",
            name: "虚拟 5.1",
            category: .surround,
            description: "模拟 5.1 声道环绕系统",
            gains: [5.5, 5.0, 2.5, -1.5, -3.5, -2.0, 1.0, 4.5, 6.5, 5.0]
        ),
        
        // 虚拟 7.1：更深声道分离 + 更强环绕
        EQPreset(
            id: "surround_71",
            name: "虚拟 7.1",
            category: .surround,
            description: "模拟 7.1 声道的精细空间定位",
            gains: [6.5, 5.0, 1.5, -2.5, -5.0, -3.5, 1.5, 5.5, 7.5, 6.5]
        ),
        
        // 沉浸人声：人声清晰居中 + 乐器环绕包围
        EQPreset(
            id: "surround_vocal",
            name: "沉浸人声",
            category: .surround,
            description: "人声居中清晰，乐器环绕包围",
            gains: [4.5, 3.5, 1.0, -2.5, -1.5, 3.0, 4.5, 3.0, 5.0, 4.5]
        ),
        
        // ═══════════════════════════════════════
        // 场景预设
        // ═══════════════════════════════════════
        
        // Live 现场：低频体感 + 临场感 + 现场空间
        EQPreset(
            id: "live",
            name: "Live 现场",
            category: .scene,
            description: "模拟大型演唱会现场的临场感",
            gains: [5.5, 5.0, 3.0, -1.5, -2.5, 1.0, 4.5, 5.5, 4.5, 3.5]
        ),
        
        // Live House：亲密近距离现场
        EQPreset(
            id: "livehouse",
            name: "Live House",
            category: .scene,
            description: "小型现场的亲密感",
            gains: [3.0, 3.5, 2.5, 1.0, 0, 2.5, 4.0, 4.5, 3.0, 1.5]
        ),
        
        // 不插电：原声乐器自然共鸣
        EQPreset(
            id: "unplugged",
            name: "不插电",
            category: .scene,
            description: "原声乐器的自然共鸣",
            gains: [1.0, 2.0, 3.5, 4.0, 1.5, 0, 2.0, 3.5, 4.0, 2.5]
        ),
        
        // 深夜：温暖低频补偿 + 高频大幅衰减
        EQPreset(
            id: "night",
            name: "深夜",
            category: .scene,
            description: "温暖柔和，适合夜间低音量聆听",
            gains: [5.0, 4.5, 3.0, 1.5, 0.5, 0, -1.0, -2.0, -3.5, -5.0]
        ),
        
        // 低音增强：纯粹的低频猛烈提升
        EQPreset(
            id: "bass_boost",
            name: "低音增强",
            category: .scene,
            description: "增强低频冲击力",
            gains: [8.5, 7.5, 5.5, 3.0, 0.5, 0, 0, 0, 0, 0]
        ),
        
        // 高音增强：高频细节和空气感大幅提升
        EQPreset(
            id: "treble_boost",
            name: "高音增强",
            category: .scene,
            description: "增强高频细节和空气感",
            gains: [0, 0, 0, 0, 0, 0.5, 2.5, 4.5, 6.5, 8.0]
        ),
        
        // 耳机优化：Harman 2019 目标曲线，低频补偿 + 近场衰减
        EQPreset(
            id: "earphone",
            name: "耳机优化",
            category: .scene,
            description: "基于 Harman 曲线优化入耳式耳机",
            gains: [4.5, 4.0, 2.5, 1.0, 0, 0, -1.5, -1.0, 1.5, 3.0]
        ),
        
        // 外放优化：手机扬声器低频大幅补偿
        EQPreset(
            id: "speaker",
            name: "外放优化",
            category: .scene,
            description: "补偿手机扬声器的低频缺失",
            gains: [8.5, 7.0, 5.0, 2.5, 0, 1.0, 1.5, 3.0, 2.5, 1.0]
        ),
        
        // ═══════════════════════════════════════
        // 人声预设
        // ═══════════════════════════════════════
        
        // 人声增强：衰减低频乐器 + 大幅提升人声频段
        EQPreset(
            id: "vocal_enhance",
            name: "人声增强",
            category: .vocal,
            description: "突出人声清晰度和气息感",
            gains: [-3.5, -2.5, -1.5, -1.0, 1.0, 4.0, 6.0, 5.0, 3.0, 1.5]
        ),
        
        // 女声优化：提升女声基频泛音 + 气息感
        EQPreset(
            id: "female_vocal",
            name: "女声优化",
            category: .vocal,
            description: "优化女声的清晰度和甜美感",
            gains: [-2.5, -1.5, 0, 1.0, 1.5, 2.5, 5.0, 6.0, 4.5, 3.0]
        ),
        
        // 男声优化：低中频温暖 + 清晰度提升
        EQPreset(
            id: "male_vocal",
            name: "男声优化",
            category: .vocal,
            description: "优化男声的温暖度和厚度",
            gains: [1.0, 2.5, 4.0, 3.5, 1.0, 3.0, 4.5, 2.5, 1.0, 0]
        ),
        
        // 播客：大幅衰减低频噪音 + 语音可懂度最大化
        EQPreset(
            id: "podcast",
            name: "播客",
            category: .vocal,
            description: "最大化语音清晰度",
            gains: [-6.0, -4.5, -2.5, 0, 1.5, 4.5, 6.5, 5.0, 1.5, -1.0]
        ),
    ]
    
    // MARK: - Init
    
    private init() {
        restoreState()
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
        currentPreset = preset
        if !isEnabled {
            isEnabled = true
        }
    }
    
    func applyFlat() {
        currentPreset = builtInPresets.first { $0.id == "flat" }
        PlayerManager.shared.equalizer.reset()
    }
    
    // MARK: - 自定义增益
    
    func setCustomGain(_ gain: Float, at index: Int) {
        guard index >= 0 && index < 10 else { return }
        customGains[index] = EQBandGain.clamped(gain)
        if isEnabled {
            let band = EQBand.allCases[index]
            PlayerManager.shared.equalizer.setGain(customGains[index], for: band)
        }
    }
    
    private func applyCustomGains() {
        for (index, band) in EQBand.allCases.enumerated() {
            if index < customGains.count {
                PlayerManager.shared.equalizer.setGain(customGains[index], for: band)
            }
        }
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
    
    private func saveState() {
        let state = EQState(
            isEnabled: isEnabled,
            currentPresetId: currentPreset?.id,
            customGains: customGains,
            customPresets: customPresets
        )
        OptimizedCacheManager.shared.setObject(state, forKey: "eq_state_v4")
    }
    
    private func restoreState() {
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
                // 迁移到 v4
                saveState()
                return
            }
        }
    }
}
