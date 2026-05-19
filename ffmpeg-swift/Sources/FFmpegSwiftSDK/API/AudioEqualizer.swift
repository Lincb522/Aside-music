// AudioEqualizer.swift
// FFmpegSwiftSDK
//
// 公开 API：音频均衡器。封装内部 EQFilter，
// 提供增益设置、预设应用、增益钳位通知等功能。

import Foundation

// MARK: - AudioEqualizerDelegate

/// 均衡器代理协议，用于接收增益钳位通知。
public protocol AudioEqualizerDelegate: AnyObject {
    /// 当请求的增益值超出有效范围 [-12 dB, +12 dB] 并被钳位时调用。
    func equalizer(_ eq: AudioEqualizer, didClampGain original: Float, to clamped: Float, for band: EQBand)
}

// MARK: - AudioEqualizer

/// 10 段音频均衡器，提供频段增益控制和预设功能。
///
/// `AudioEqualizer` 封装内部 `EQFilter`，提供安全的公开 API。
/// 当增益值超出 [-12, +12] dB 范围时，会被钳位到最近边界并通知代理。
///
/// 通过 `StreamPlayer.equalizer` 访问。
///
/// 使用示例：
/// ```swift
/// let player = StreamPlayer()
/// player.equalizer.delegate = self
/// player.equalizer.setGain(6.0, for: .hz125)
/// player.equalizer.applyPreset(.rock)
/// player.equalizer.reset()
/// ```
public final class AudioEqualizer {

    // MARK: - 属性

    /// 代理，用于接收增益钳位通知
    public weak var delegate: AudioEqualizerDelegate?

    /// 内部 EQ 滤波器
    internal let filter: EQFilter
    
    /// 音频效果控制器引用（用于应用预设的环绕效果）
    internal weak var audioEffects: AudioEffects?
    
    /// 当前应用的预设
    public private(set) var currentPreset: EQPreset?
    
    /// 预设变化回调
    public var onPresetChanged: ((EQPreset?) -> Void)?

    // MARK: - 初始化

    internal init(filter: EQFilter) {
        self.filter = filter
    }

    // MARK: - 公开 API

    /// 设置指定频段的增益。
    ///
    /// 如果值超出有效范围 [-12.0, +12.0] dB，会被钳位到最近边界，
    /// 并通过 `equalizer(_:didClampGain:to:for:)` 通知代理。
    ///
    /// 线程安全。
    public func setGain(_ gainDB: Float, for band: EQBand) {
        let clamped = filter.setGain(gainDB, for: band)
        if clamped != gainDB {
            delegate?.equalizer(self, didClampGain: gainDB, to: clamped, for: band)
        }
        // 手动调整增益后清除当前预设
        currentPreset = nil
    }

    /// 返回指定频段的当前增益。
    ///
    /// 线程安全。
    public func gain(for band: EQBand) -> Float {
        return filter.gain(for: band)
    }

    /// 重置所有频段增益为 0 dB。
    ///
    /// 线程安全。
    public func reset() {
        filter.reset()
        currentPreset = nil
        onPresetChanged?(nil)
    }
    
    // MARK: - 预设功能
    
    /// 应用 EQ 预设
    ///
    /// 会同时设置：
    /// - 各频段增益
    /// - 环绕效果强度（如果预设包含）
    /// - 立体声宽度（如果预设包含）
    /// - 低音/高音增益（如果预设包含）
    ///
    /// - Parameter preset: 要应用的预设
    public func applyPreset(_ preset: EQPreset) {
        // 应用各频段增益
        for band in EQBand.allCases {
            let gain = preset.gains[band] ?? 0.0
            _ = filter.setGain(gain, for: band)
        }
        
        // 应用环绕效果
        if let effects = audioEffects {
            if preset.surroundLevel > 0 {
                effects.setSurroundLevel(preset.surroundLevel)
            }
            
            if preset.stereoWidth != 1.0 {
                effects.setStereoWidth(preset.stereoWidth)
            }
            
            if preset.bassBoost != 0 {
                effects.setBassGain(preset.bassBoost)
            }
            
            if preset.trebleBoost != 0 {
                effects.setTrebleGain(preset.trebleBoost)
            }
        }
        
        currentPreset = preset
        onPresetChanged?(preset)
    }
    
    /// 通过预设 ID 应用预设
    ///
    /// - Parameter presetId: 预设 ID
    /// - Returns: 是否成功找到并应用预设
    @discardableResult
    public func applyPreset(id presetId: String) -> Bool {
        guard let preset = EQPresets.all.first(where: { $0.id == presetId }) else {
            return false
        }
        applyPreset(preset)
        return true
    }
    
    /// 获取所有可用预设
    public var availablePresets: [EQPreset] {
        return EQPresets.all
    }
    
    /// 获取按分类组织的预设
    public var presetsByCategory: [(category: String, presets: [EQPreset])] {
        return EQPresets.byCategory
    }
}
