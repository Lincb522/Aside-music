// EQBand.swift
// FFmpegSwiftSDK
//
// Defines the EQ frequency bands and gain parameters for the audio equalizer.
// 10-band parametric EQ covering 31 Hz to 16 kHz for HiFi-grade audio control.

import Foundation

/// Represents the ten frequency bands of the audio equalizer.
///
/// Standard 10-band EQ with ISO center frequencies covering the full
/// audible spectrum from sub-bass to brilliance.
public enum EQBand: Int, CaseIterable, Comparable {
    /// Sub-bass: 31 Hz
    case hz31 = 0
    /// Bass: 62 Hz
    case hz62 = 1
    /// Low-mid: 125 Hz
    case hz125 = 2
    /// Mid: 250 Hz
    case hz250 = 3
    /// Mid: 500 Hz
    case hz500 = 4
    /// Upper-mid: 1 kHz
    case hz1k = 5
    /// Presence: 2 kHz
    case hz2k = 6
    /// Brilliance: 4 kHz
    case hz4k = 7
    /// Brilliance: 8 kHz
    case hz8k = 8
    /// Air: 16 kHz
    case hz16k = 9

    /// The center frequency of this band, in Hz.
    public var centerFrequency: Float {
        switch self {
        case .hz31:  return 31
        case .hz62:  return 62
        case .hz125: return 125
        case .hz250: return 250
        case .hz500: return 500
        case .hz1k:  return 1000
        case .hz2k:  return 2000
        case .hz4k:  return 4000
        case .hz8k:  return 8000
        case .hz16k: return 16000
        }
    }

    /// 每个频段的 Q 值（带宽控制）。
    /// 低频段用更低的 Q（更宽带宽）以获得更饱满的低频体感，
    /// 高频段用稍高的 Q 以保持精确度。
    /// 整体比默认 Q=1.0 更宽，让 10 段之间无缝衔接。
    public var q: Float {
        switch self {
        case .hz31:  return 0.5   // 超低频需要宽带宽
        case .hz62:  return 0.6
        case .hz125: return 0.7
        case .hz250: return 0.7
        case .hz500: return 0.8
        case .hz1k:  return 0.8
        case .hz2k:  return 0.8
        case .hz4k:  return 0.7
        case .hz8k:  return 0.6
        case .hz16k: return 0.5   // 超高频也需要宽带宽
        }
    }

    /// Human-readable label for this band.
    public var label: String {
        switch self {
        case .hz31:  return "31"
        case .hz62:  return "62"
        case .hz125: return "125"
        case .hz250: return "250"
        case .hz500: return "500"
        case .hz1k:  return "1k"
        case .hz2k:  return "2k"
        case .hz4k:  return "4k"
        case .hz8k:  return "8k"
        case .hz16k: return "16k"
        }
    }

    public static func < (lhs: EQBand, rhs: EQBand) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Represents a gain setting for a specific EQ frequency band.
public struct EQBandGain {
    public let band: EQBand
    public let gainDB: Float

    public static let minGain: Float = -12.0
    public static let maxGain: Float = 12.0

    public static func clamped(_ value: Float) -> Float {
        min(max(value, minGain), maxGain)
    }

    public init(band: EQBand, gainDB: Float) {
        self.band = band
        self.gainDB = gainDB
    }
}

// MARK: - EQ 预设

/// EQ 预设，包含各频段增益和可选的环绕效果设置
public struct EQPreset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let gains: [EQBand: Float]
    /// 环绕效果强度（0~1），0 表示不启用
    public let surroundLevel: Float
    /// 立体声宽度（0~2），1.0 表示不改变
    public let stereoWidth: Float
    /// 低音增益（dB）
    public let bassBoost: Float
    /// 高音增益（dB）
    public let trebleBoost: Float
    
    public init(
        id: String,
        name: String,
        description: String,
        gains: [EQBand: Float],
        surroundLevel: Float = 0,
        stereoWidth: Float = 1.0,
        bassBoost: Float = 0,
        trebleBoost: Float = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.gains = gains
        self.surroundLevel = surroundLevel
        self.stereoWidth = stereoWidth
        self.bassBoost = bassBoost
        self.trebleBoost = trebleBoost
    }
    
    public static func == (lhs: EQPreset, rhs: EQPreset) -> Bool {
        lhs.id == rhs.id
    }
}

/// 内置 EQ 预设集合
public enum EQPresets {
    
    // MARK: - 基础预设
    
    /// 平坦（默认）
    public static let flat = EQPreset(
        id: "flat",
        name: "平坦",
        description: "无调整，原始音色",
        gains: [:]
    )
    
    /// 低音增强
    public static let bassBoost = EQPreset(
        id: "bass_boost",
        name: "低音增强",
        description: "增强低频，适合流行、电子音乐",
        gains: [
            .hz31: 6.0, .hz62: 5.0, .hz125: 4.0, .hz250: 2.0,
            .hz500: 0, .hz1k: 0, .hz2k: 0, .hz4k: 0, .hz8k: 0, .hz16k: 0
        ],
        bassBoost: 3.0
    )
    
    /// 高音增强
    public static let trebleBoost = EQPreset(
        id: "treble_boost",
        name: "高音增强",
        description: "增强高频，提升清晰度和细节",
        gains: [
            .hz31: 0, .hz62: 0, .hz125: 0, .hz250: 0,
            .hz500: 0, .hz1k: 1.0, .hz2k: 2.0, .hz4k: 4.0, .hz8k: 5.0, .hz16k: 6.0
        ],
        trebleBoost: 3.0
    )
    
    /// 人声增强
    public static let vocal = EQPreset(
        id: "vocal",
        name: "人声增强",
        description: "突出人声频段，适合播客、有声书",
        gains: [
            .hz31: -2.0, .hz62: -1.0, .hz125: 0, .hz250: 1.0,
            .hz500: 3.0, .hz1k: 4.0, .hz2k: 4.0, .hz4k: 3.0, .hz8k: 1.0, .hz16k: 0
        ]
    )
    
    // MARK: - 音乐风格预设
    
    /// 摇滚
    public static let rock = EQPreset(
        id: "rock",
        name: "摇滚",
        description: "增强低频和高频，V 型曲线",
        gains: [
            .hz31: 5.0, .hz62: 4.0, .hz125: 2.0, .hz250: 0,
            .hz500: -1.0, .hz1k: 0, .hz2k: 1.0, .hz4k: 3.0, .hz8k: 4.0, .hz16k: 5.0
        ],
        surroundLevel: 0.2,
        bassBoost: 2.0
    )
    
    /// 流行
    public static let pop = EQPreset(
        id: "pop",
        name: "流行",
        description: "均衡明亮，适合流行音乐",
        gains: [
            .hz31: 1.0, .hz62: 2.0, .hz125: 3.0, .hz250: 2.0,
            .hz500: 0, .hz1k: 0, .hz2k: 1.0, .hz4k: 2.0, .hz8k: 3.0, .hz16k: 2.0
        ],
        surroundLevel: 0.15
    )
    
    /// 古典
    public static let classical = EQPreset(
        id: "classical",
        name: "古典",
        description: "宽广动态，自然音色",
        gains: [
            .hz31: 0, .hz62: 0, .hz125: 0, .hz250: 0,
            .hz500: 0, .hz1k: 0, .hz2k: 0, .hz4k: 1.0, .hz8k: 2.0, .hz16k: 2.0
        ],
        stereoWidth: 1.2
    )
    
    /// 爵士
    public static let jazz = EQPreset(
        id: "jazz",
        name: "爵士",
        description: "温暖饱满，突出乐器质感",
        gains: [
            .hz31: 2.0, .hz62: 3.0, .hz125: 2.0, .hz250: 1.0,
            .hz500: 0, .hz1k: 0, .hz2k: 1.0, .hz4k: 2.0, .hz8k: 2.0, .hz16k: 1.0
        ],
        stereoWidth: 1.1
    )
    
    /// 电子/EDM
    public static let electronic = EQPreset(
        id: "electronic",
        name: "电子/EDM",
        description: "强劲低频，明亮高频",
        gains: [
            .hz31: 6.0, .hz62: 5.0, .hz125: 3.0, .hz250: 0,
            .hz500: -1.0, .hz1k: 0, .hz2k: 2.0, .hz4k: 4.0, .hz8k: 5.0, .hz16k: 4.0
        ],
        surroundLevel: 0.3,
        bassBoost: 4.0
    )
    
    /// 嘻哈/R&B
    public static let hiphop = EQPreset(
        id: "hiphop",
        name: "嘻哈/R&B",
        description: "深沉低频，清晰人声",
        gains: [
            .hz31: 5.0, .hz62: 4.0, .hz125: 2.0, .hz250: 1.0,
            .hz500: 0, .hz1k: 1.0, .hz2k: 2.0, .hz4k: 1.0, .hz8k: 0, .hz16k: 0
        ],
        bassBoost: 3.0
    )
    
    // MARK: - 环绕效果预设
    
    /// 3D 环绕
    public static let surround3D = EQPreset(
        id: "surround_3d",
        name: "3D 环绕",
        description: "增强立体声分离度，沉浸式体验",
        gains: [
            .hz31: 1.0, .hz62: 1.0, .hz125: 0, .hz250: 0,
            .hz500: 0, .hz1k: 0, .hz2k: 1.0, .hz4k: 2.0, .hz8k: 2.0, .hz16k: 1.0
        ],
        surroundLevel: 0.5,
        stereoWidth: 1.4
    )
    
    /// 影院模式
    public static let cinema = EQPreset(
        id: "cinema",
        name: "影院模式",
        description: "宽广声场，适合观影",
        gains: [
            .hz31: 4.0, .hz62: 3.0, .hz125: 2.0, .hz250: 0,
            .hz500: 0, .hz1k: 0, .hz2k: 1.0, .hz4k: 2.0, .hz8k: 3.0, .hz16k: 2.0
        ],
        surroundLevel: 0.6,
        stereoWidth: 1.5,
        bassBoost: 2.0
    )
    
    /// 演唱会
    public static let concert = EQPreset(
        id: "concert",
        name: "演唱会",
        description: "现场感，空间混响",
        gains: [
            .hz31: 3.0, .hz62: 2.0, .hz125: 1.0, .hz250: 0,
            .hz500: 0, .hz1k: 1.0, .hz2k: 2.0, .hz4k: 3.0, .hz8k: 3.0, .hz16k: 2.0
        ],
        surroundLevel: 0.4,
        stereoWidth: 1.3
    )
    
    /// 宽广立体声
    public static let wideStereo = EQPreset(
        id: "wide_stereo",
        name: "宽广立体声",
        description: "扩展立体声宽度",
        gains: [:],
        surroundLevel: 0.3,
        stereoWidth: 1.6
    )
    
    // MARK: - 设备优化预设
    
    /// 耳机优化
    public static let headphones = EQPreset(
        id: "headphones",
        name: "耳机优化",
        description: "针对耳机优化的频响曲线",
        gains: [
            .hz31: 2.0, .hz62: 1.0, .hz125: 0, .hz250: 0,
            .hz500: 0, .hz1k: 0, .hz2k: 1.0, .hz4k: 2.0, .hz8k: 1.0, .hz16k: 0
        ],
        stereoWidth: 0.9  // 耳机略微收窄立体声更自然
    )
    
    /// 小音箱
    public static let smallSpeaker = EQPreset(
        id: "small_speaker",
        name: "小音箱",
        description: "补偿小音箱的低频不足",
        gains: [
            .hz31: 6.0, .hz62: 5.0, .hz125: 4.0, .hz250: 2.0,
            .hz500: 0, .hz1k: 0, .hz2k: 1.0, .hz4k: 2.0, .hz8k: 2.0, .hz16k: 1.0
        ],
        bassBoost: 4.0
    )
    
    /// 车载
    public static let car = EQPreset(
        id: "car",
        name: "车载",
        description: "针对车内环境优化",
        gains: [
            .hz31: 3.0, .hz62: 2.0, .hz125: 1.0, .hz250: 0,
            .hz500: 0, .hz1k: 1.0, .hz2k: 2.0, .hz4k: 3.0, .hz8k: 2.0, .hz16k: 1.0
        ],
        surroundLevel: 0.2,
        bassBoost: 2.0
    )
    
    // MARK: - 特殊效果预设
    
    /// 夜间模式
    public static let nightMode = EQPreset(
        id: "night_mode",
        name: "夜间模式",
        description: "降低低频，保护邻居",
        gains: [
            .hz31: -4.0, .hz62: -3.0, .hz125: -2.0, .hz250: 0,
            .hz500: 0, .hz1k: 1.0, .hz2k: 1.0, .hz4k: 0, .hz8k: 0, .hz16k: 0
        ],
        bassBoost: -3.0
    )
    
    /// 语音清晰
    public static let speechClarity = EQPreset(
        id: "speech_clarity",
        name: "语音清晰",
        description: "增强语音清晰度，适合会议、播客",
        gains: [
            .hz31: -3.0, .hz62: -2.0, .hz125: -1.0, .hz250: 0,
            .hz500: 2.0, .hz1k: 3.0, .hz2k: 4.0, .hz4k: 3.0, .hz8k: 1.0, .hz16k: 0
        ]
    )
    
    // MARK: - 所有预设
    
    /// 所有内置预设
    public static let all: [EQPreset] = [
        flat,
        bassBoost,
        trebleBoost,
        vocal,
        rock,
        pop,
        classical,
        jazz,
        electronic,
        hiphop,
        surround3D,
        cinema,
        concert,
        wideStereo,
        headphones,
        smallSpeaker,
        car,
        nightMode,
        speechClarity
    ]
    
    /// 按分类获取预设
    public static let byCategory: [(category: String, presets: [EQPreset])] = [
        ("基础", [flat, bassBoost, trebleBoost, vocal]),
        ("音乐风格", [rock, pop, classical, jazz, electronic, hiphop]),
        ("环绕效果", [surround3D, cinema, concert, wideStereo]),
        ("设备优化", [headphones, smallSpeaker, car]),
        ("特殊效果", [nightMode, speechClarity])
    ]
}
