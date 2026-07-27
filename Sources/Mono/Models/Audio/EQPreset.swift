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
    
    var icon: MonoIcon.IconType {
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
    case graphic32   // 32 段三分之一倍频程图示均衡器
    case super18     // 18 段 superequalizer（已废弃，仅用于旧数据兼容）

    var graphicMode: GraphicEQMode? {
        switch self {
        case .standard10: return .tenBand
        case .graphic32: return .thirtyTwoBand
        case .super18: return nil
        }
    }

    var expectedGainCount: Int {
        switch self {
        case .standard10: return GraphicEQMode.tenBand.bandCount
        case .graphic32: return GraphicEQMode.thirtyTwoBand.bandCount
        case .super18: return 18
        }
    }
}

/// Additional realtime processing paired with an internal graphic-EQ family.
/// Curves remain separate for 10/32 bands; this profile defines the shared
/// mastering intent without duplicating it across both JSON resources.
struct EQPresetProcessingProfile: Equatable {
    let bassGain: Float
    let trebleGain: Float
    let effects: MonoEffectTuningConfiguration

    static let reference = EQPresetProcessingProfile(
        bassGain: 0,
        trebleGain: 0,
        effects: .neutral
    )
}

/// EQ 预设
struct EQPreset: Identifiable, Codable, Equatable {
    let id: String
    /// 同一听感预设在 10 段与 32 段资源中的稳定对应标识。
    let familyID: String
    let name: String
    let category: EQPresetCategory
    let description: String
    /// 按 `presetType` 对应中心频率升序排列的增益值。
    let gains: [Float]
    /// 是否为用户自定义
    let isCustom: Bool
    /// 预设类型
    let presetType: EQPresetType
    /// 环绕强度（0~1），仅环绕类预设有效
    let surroundLevel: Float
    /// 混响强度（0~1），仅环绕类预设有效
    let reverbLevel: Float
    /// 立体声宽度（0~2），1.0 = 原始
    let stereoWidth: Float
    /// 该预设独立的前级值。nil 时由完整滤波曲线自动计算。
    let preampDB: Float?
    /// 等响 A/B 的人工微调值。nil 时使用感知权重自动匹配。
    let loudnessCompensationDB: Float?
    
    init(id: String, familyID: String? = nil, name: String, category: EQPresetCategory, description: String, gains: [Float], isCustom: Bool = false, presetType: EQPresetType = .standard10, surroundLevel: Float = 0, reverbLevel: Float = 0, stereoWidth: Float = 1.0, preampDB: Float? = nil, loudnessCompensationDB: Float? = nil) {
        self.id = id
        self.familyID = familyID ?? id
        self.name = name
        self.category = category
        self.description = description
        self.presetType = presetType
        self.gains = gains.count == presetType.expectedGainCount
            ? gains
            : Array(repeating: 0, count: presetType.expectedGainCount)
        self.isCustom = isCustom
        self.surroundLevel = surroundLevel
        self.reverbLevel = reverbLevel
        self.stereoWidth = stereoWidth
        self.preampDB = preampDB.map { min(max($0, -18), 0) }
        self.loudnessCompensationDB = loudnessCompensationDB.map { min(max($0, -12), 3) }
    }
    
    // MARK: - 自定义 Decodable（JSON 中可省略有默认值的字段）
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        familyID = try container.decodeIfPresent(String.self, forKey: .familyID) ?? id
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(EQPresetCategory.self, forKey: .category)
        description = try container.decode(String.self, forKey: .description)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        presetType = try container.decodeIfPresent(EQPresetType.self, forKey: .presetType) ?? .standard10
        let rawGains = try container.decode([Float].self, forKey: .gains)
        gains = rawGains.count == presetType.expectedGainCount
            ? rawGains
            : Array(repeating: 0, count: presetType.expectedGainCount)
        surroundLevel = try container.decodeIfPresent(Float.self, forKey: .surroundLevel) ?? 0
        reverbLevel = try container.decodeIfPresent(Float.self, forKey: .reverbLevel) ?? 0
        stereoWidth = try container.decodeIfPresent(Float.self, forKey: .stereoWidth) ?? 1.0
        preampDB = try container.decodeIfPresent(Float.self, forKey: .preampDB)
        loudnessCompensationDB = try container.decodeIfPresent(Float.self, forKey: .loudnessCompensationDB)
    }
    
    /// 应用预设到均衡器和音效
    func apply(to equalizer: AudioEqualizer) {
        guard let mode = presetType.graphicMode else { return }
        equalizer.setGraphicMode(mode, gainsDB: gains)
    }

    func gains(in mode: GraphicEQMode) -> [Float] {
        guard let sourceMode = presetType.graphicMode else {
            return Array(repeating: 0, count: mode.bandCount)
        }
        return mode.resampledGains(gains, from: sourceMode)
    }
    
    /// 应用环绕音效参数（仅环绕类预设）
    func applySurroundEffects(to effects: AudioEffects) {
        guard category == .surround else { return }
        effects.setSurroundLevel(surroundLevel)
        effects.setReverbLevel(reverbLevel)
        effects.setStereoWidth(stereoWidth)
    }

    /// Static presets avoid loudness normalization because track LUFS is
    /// unknown. Measured loudness work remains owned by Mono Audio Agent.
    var processingProfile: EQPresetProcessingProfile {
        switch familyID {
        case "flat":
            return .reference
        case "pop", "chinese", "jpop", "kpop_stage":
            return Self.profile(finalCeiling: -1)
        case "rock", "metal", "funk_snap", "workout", "livehouse":
            return Self.profile(
                bass: 0.25,
                treble: 0.15,
                compressor: (-15, 1.35, 16, 160, 0),
                finalCeiling: -1.1
            )
        case "electronic", "house_punch", "techno_edge", "party_mode":
            return Self.profile(
                bass: 0.3,
                treble: 0.15,
                compressor: (-16, 1.45, 12, 140, 0),
                subboost: (1.1, 78),
                exciter: (0.35, 7_200),
                finalCeiling: -1.2
            )
        case "hiphop", "trap_sub", "drum_bass", "bass_boost", "reggae_groove", "surround_bass":
            return Self.profile(
                bass: 0.4,
                treble: -0.1,
                compressor: (-17, 1.35, 20, 190, 0),
                subboost: (2, 72),
                finalCeiling: -1.4
            )
        case "classical", "jazz", "acoustic", "country_open", "unplugged":
            return Self.profile(bass: -0.1, treble: 0.1, finalCeiling: -0.8)
        case "rnb", "soul_warm", "blues_tube", "lofi_chill", "vinyl_warm", "speech_warm":
            return Self.profile(
                bass: 0.2,
                treble: -0.25,
                compressor: (-17, 1.2, 28, 250, 0),
                softclipType: 0,
                finalCeiling: -1.2
            )
        case "indie_air", "treble_boost", "female_vocal":
            return Self.profile(
                bass: -0.15,
                treble: 0.3,
                exciter: (0.35, 6_500),
                finalCeiling: -1
            )
        case "live", "surround_front_row", "surround_open_air", "surround_stadium", "surround_cinema":
            return Self.profile(
                bass: 0.15,
                treble: 0.1,
                compressor: (-18, 1.3, 22, 220, 0),
                finalCeiling: -1.1
            )
        case "night", "sleep_soft":
            return Self.profile(
                bass: -0.35,
                treble: -0.45,
                compressor: (-24, 2.1, 35, 350, 1.2),
                finalCeiling: -1.8
            )
        case "earphone", "surround_binaural":
            return Self.profile(
                bass: 0.05,
                treble: 0.1,
                bs2b: (700, 45),
                finalCeiling: -1
            )
        case "speaker":
            return Self.profile(
                treble: 0.15,
                compressor: (-17, 1.35, 20, 200, 0),
                virtualBass: (180, 1.8),
                finalCeiling: -1.3
            )
        case "commute", "airplane_noisecut", "car_cabin":
            return Self.profile(
                bass: 0.1,
                treble: 0.2,
                compressor: (-20, 1.65, 20, 260, 0.7),
                finalCeiling: -1.4
            )
        case "study_focus":
            return Self.profile(bass: -0.2, treble: 0.1, finalCeiling: -1)
        case "gaming_fps", "surround_arcade":
            return Self.profile(
                bass: -0.2,
                treble: 0.35,
                compressor: (-16, 1.2, 10, 130, 0),
                exciter: (0.45, 4_500),
                finalCeiling: -1
            )
        case "asmr_detail":
            return Self.profile(
                bass: -0.2,
                treble: 0.2,
                crossfeed: 0.1,
                exciter: (0.2, 5_500),
                finalCeiling: -1.2
            )
        case "vocal_enhance":
            // Keep the vocal lift in the graphic curve. Adding a low-frequency
            // tone cut, compressor makeup and a 3.8 kHz exciter on top of that
            // made dense masters sound grainy and could expose codec crackle on
            // Bluetooth. This profile retains presence without synthesizing
            // another layer of upper-mid harmonics.
            return Self.profile(
                bass: -0.2,
                treble: 0.1,
                compressor: (-18, 1.3, 24, 220, 0),
                finalCeiling: -1.5
            )
        case "male_vocal", "podcast", "karaoke_clear", "speech_bright", "live_mc", "audiobook", "anime_dialogue", "surround_vocal", "surround_dialogue_dome":
            return Self.profile(
                bass: -0.3,
                treble: 0.25,
                compressor: (-20, 1.7, 15, 200, 0.5),
                exciter: (0.2, 3_800),
                finalCeiling: -1.2
            )
        case "deesser_soft":
            return Self.profile(
                bass: -0.1,
                treble: -0.35,
                compressor: (-18, 1.3, 12, 180, 0),
                finalCeiling: -1
            )
        case "intimate_whisper":
            return Self.profile(
                bass: -0.15,
                treble: 0.15,
                compressor: (-26, 1.6, 30, 320, 0.8),
                crossfeed: 0.12,
                finalCeiling: -1.5
            )
        case "surround_studio", "surround_blackbox":
            return Self.profile(finalCeiling: -0.8)
        case "surround_3d", "surround_concert_hall", "surround_church", "surround_wide", "surround_51", "surround_71", "surround_holographic", "surround_ambient_dream", "surround_auditorium", "surround_midnight_hall":
            return Self.profile(treble: -0.1, finalCeiling: -1.2)
        default:
            return Self.profile(finalCeiling: -1)
        }
    }

    private static func profile(
        bass: Float = 0,
        treble: Float = 0,
        compressor: (threshold: Float, ratio: Float, attack: Float, release: Float, makeup: Float)? = nil,
        subboost: (gain: Float, cutoff: Float)? = nil,
        bs2b: (cutoff: Int, feed: Int)? = nil,
        crossfeed: Float? = nil,
        virtualBass: (cutoff: Float, strength: Float)? = nil,
        exciter: (amount: Float, frequency: Float)? = nil,
        softclipType: Int? = nil,
        finalCeiling: Float
    ) -> EQPresetProcessingProfile {
        EQPresetProcessingProfile(
            bassGain: bass,
            trebleGain: treble,
            effects: MonoEffectTuningConfiguration(
                compressorEnabled: compressor != nil,
                compressorThresholdDB: compressor?.threshold ?? -18,
                compressorRatio: compressor?.ratio ?? 2,
                compressorAttackMS: compressor?.attack ?? 18,
                compressorReleaseMS: compressor?.release ?? 180,
                compressorMakeupDB: compressor?.makeup ?? 0,
                subboostEnabled: subboost != nil,
                subboostGainDB: subboost?.gain ?? 0,
                subboostCutoffHz: subboost?.cutoff ?? 90,
                bs2bEnabled: bs2b != nil,
                bs2bCutoffHz: bs2b?.cutoff ?? 700,
                bs2bFeed: bs2b?.feed ?? 50,
                crossfeedEnabled: crossfeed != nil,
                crossfeedStrength: crossfeed ?? 0.2,
                virtualBassEnabled: virtualBass != nil,
                virtualBassCutoffHz: virtualBass?.cutoff ?? 180,
                virtualBassStrength: virtualBass?.strength ?? 0,
                exciterEnabled: exciter != nil,
                exciterAmountDB: exciter?.amount ?? 0,
                exciterFrequencyHz: exciter?.frequency ?? 7_500,
                softclipEnabled: softclipType != nil,
                softclipType: softclipType ?? 0,
                finalLimiterEnabled: true,
                finalLimiterCeilingDB: finalCeiling
            )
        )
    }
    
    static func == (lhs: EQPreset, rhs: EQPreset) -> Bool {
        lhs.id == rhs.id
    }
}
