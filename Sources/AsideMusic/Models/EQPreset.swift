// EQPreset.swift
// AsideMusic
//
// EQ 预设模型，包含专业级均衡器预设数据
// 所有预设基于音频工程标准参数，参考 ITU-R BS.1770、AES 标准

import Foundation
import FFmpegSwiftSDK

/// EQ 预设分类
enum EQPresetCategory: String, CaseIterable, Codable {
    case flat = "默认"
    case genre = "音乐风格"
    case surround = "环绕"
    case scene = "场景"
    case vocal = "人声"
    case custom = "自定义"
    
    var icon: AsideIcon.IconType {
        switch self {
        case .flat: return .waveform
        case .genre: return .musicNote
        case .surround: return .headphones
        case .scene: return .sparkle
        case .vocal: return .podcast
        case .custom: return .settings
        }
    }
}

/// EQ 预设类型
enum EQPresetType: String, Codable {
    case standard10  // 10 段 biquad
    case super18     // 18 段 superequalizer（已废弃，仅用于旧数据兼容）
}

/// EQ 预设
struct EQPreset: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let category: EQPresetCategory
    let description: String
    /// 10 段增益值 (dB)，顺序: 31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
    let gains: [Float]
    /// 是否为用户自定义
    let isCustom: Bool
    /// 预设类型
    let presetType: EQPresetType
    
    init(id: String, name: String, category: EQPresetCategory, description: String, gains: [Float], isCustom: Bool = false, presetType: EQPresetType = .standard10) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.presetType = presetType
        self.gains = gains.count == 10 ? gains : Array(repeating: 0, count: 10)
        self.isCustom = isCustom
    }
    
    /// 应用预设到均衡器
    func apply(to equalizer: AudioEqualizer) {
        guard presetType == .standard10 else { return }
        for (index, band) in EQBand.allCases.enumerated() {
            if index < gains.count {
                equalizer.setGain(gains[index], for: band)
            }
        }
    }
    
    static func == (lhs: EQPreset, rhs: EQPreset) -> Bool {
        lhs.id == rhs.id
    }
}
