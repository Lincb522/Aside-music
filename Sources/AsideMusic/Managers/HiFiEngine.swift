//
//  HiFiEngine.swift
//  AsideMusic
//
//  HiFi 音频引擎 - 提供专业级音频增强效果
//  包含：空间音效、3D环绕、动态压缩、低音增强、响度均衡
//

import AVFoundation
import Accelerate

// MARK: - HiFi Effect Types

/// 空间音效模式
enum SpatialMode: String, CaseIterable, Identifiable, Codable {
    case off = "关闭"
    case wide = "宽广"
    case concert = "音乐厅"
    case club = "俱乐部"
    case theater = "剧院"
    
    var id: String { rawValue }
    
    /// 立体声宽度系数 (0-1)
    var widthFactor: Float {
        switch self {
        case .off: return 0
        case .wide: return 0.4
        case .concert: return 0.6
        case .club: return 0.3
        case .theater: return 0.8
        }
    }
    
    /// 混响量
    var reverbMix: Float {
        switch self {
        case .off: return 0
        case .wide: return 0.1
        case .concert: return 0.35
        case .club: return 0.2
        case .theater: return 0.45
        }
    }
}


/// 3D 环绕模式
enum Surround3DMode: String, CaseIterable, Identifiable, Codable {
    case off = "关闭"
    case subtle = "轻微"
    case moderate = "适中"
    case immersive = "沉浸"
    
    var id: String { rawValue }
    
    /// Crossfeed 强度 (0-1)
    var crossfeedLevel: Float {
        switch self {
        case .off: return 0
        case .subtle: return 0.15
        case .moderate: return 0.3
        case .immersive: return 0.5
        }
    }
    
    /// 延迟时间 (毫秒)
    var delayMs: Float {
        switch self {
        case .off: return 0
        case .subtle: return 0.3
        case .moderate: return 0.5
        case .immersive: return 0.8
        }
    }
}

/// 低音增强模式
enum BassBoostMode: String, CaseIterable, Identifiable, Codable {
    case off = "关闭"
    case light = "轻度"
    case medium = "中度"
    case heavy = "重度"
    case extreme = "极限"
    
    var id: String { rawValue }
    
    /// 增益 dB
    var gainDb: Float {
        switch self {
        case .off: return 0
        case .light: return 3
        case .medium: return 6
        case .heavy: return 9
        case .extreme: return 12
        }
    }
}


// MARK: - HiFi Engine Manager

@MainActor
final class HiFiEngine: ObservableObject {
    static let shared = HiFiEngine()
    
    // MARK: - Published Properties
    
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "hifi_enabled")
            processor?.setEnabled(isEnabled)
        }
    }
    
    @Published var spatialMode: SpatialMode = .off {
        didSet {
            UserDefaults.standard.set(spatialMode.rawValue, forKey: "hifi_spatial")
            updateProcessor()
        }
    }
    
    @Published var surround3D: Surround3DMode = .off {
        didSet {
            UserDefaults.standard.set(surround3D.rawValue, forKey: "hifi_surround")
            updateProcessor()
        }
    }
    
    @Published var bassBoost: BassBoostMode = .off {
        didSet {
            UserDefaults.standard.set(bassBoost.rawValue, forKey: "hifi_bass")
            updateProcessor()
        }
    }
    
    @Published var dynamicRange: Bool = false {
        didSet {
            UserDefaults.standard.set(dynamicRange, forKey: "hifi_dynamic")
            updateProcessor()
        }
    }
    
    @Published var loudnessNorm: Bool = false {
        didSet {
            UserDefaults.standard.set(loudnessNorm, forKey: "hifi_loudness")
            updateProcessor()
        }
    }
    
    // MARK: - Internal
    
    nonisolated(unsafe) var processor: HiFiProcessor?
    
    // MARK: - Init
    
    private init() {
        restoreSettings()
        processor = HiFiProcessor()
        updateProcessor()
    }

    
    private func restoreSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "hifi_enabled")
        
        if let spatial = UserDefaults.standard.string(forKey: "hifi_spatial"),
           let mode = SpatialMode(rawValue: spatial) {
            spatialMode = mode
        }
        
        if let surround = UserDefaults.standard.string(forKey: "hifi_surround"),
           let mode = Surround3DMode(rawValue: surround) {
            surround3D = mode
        }
        
        if let bass = UserDefaults.standard.string(forKey: "hifi_bass"),
           let mode = BassBoostMode(rawValue: bass) {
            bassBoost = mode
        }
        
        dynamicRange = UserDefaults.standard.bool(forKey: "hifi_dynamic")
        loudnessNorm = UserDefaults.standard.bool(forKey: "hifi_loudness")
    }
    
    private func updateProcessor() {
        processor?.configure(
            spatialWidth: spatialMode.widthFactor,
            reverbMix: spatialMode.reverbMix,
            crossfeed: surround3D.crossfeedLevel,
            crossfeedDelay: surround3D.delayMs,
            bassGain: bassBoost.gainDb,
            dynamicRange: dynamicRange,
            loudnessNorm: loudnessNorm
        )
    }
    
    /// 重置所有设置
    func reset() {
        spatialMode = .off
        surround3D = .off
        bassBoost = .off
        dynamicRange = false
        loudnessNorm = false
    }
}


// MARK: - HiFi Audio Processor

final class HiFiProcessor {
    
    // 效果参数
    private var spatialWidth: Float = 0
    private var reverbMix: Float = 0
    private var crossfeed: Float = 0
    private var crossfeedDelaySamples: Int = 0
    private var bassGain: Float = 0
    private var dynamicRangeEnabled: Bool = false
    private var loudnessNormEnabled: Bool = false
    
    private var isEnabled: Bool = false
    private let lock = NSLock()
    
    // 延迟缓冲区 (用于 crossfeed)
    private var delayBufferL: [Float] = []
    private var delayBufferR: [Float] = []
    private var delayIndex: Int = 0
    
    // 低音滤波器
    private var bassFilter: BiquadFilter?
    
    // 动态压缩状态
    private var compressorGain: Float = 1.0
    
    // 响度均衡状态
    private var loudnessGain: Float = 1.0
    private var loudnessRMS: Float = 0
    
    private var sampleRate: Float = 44100
    
    init() {
        // 使用低频搁架滤波器来增强低音
        bassFilter = BiquadFilter(frequency: 100, gain: 6, q: 0.7, sampleRate: sampleRate, type: .lowShelf)
        setupDelayBuffer()
    }
    
    private func setupDelayBuffer() {
        // 增加延迟缓冲区大小以支持更明显的效果
        let maxDelaySamples = Int(sampleRate * 0.01) // 10ms max
        delayBufferL = [Float](repeating: 0, count: max(maxDelaySamples, 512))
        delayBufferR = [Float](repeating: 0, count: max(maxDelaySamples, 512))
        delayIndex = 0
    }

    
    func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        isEnabled = enabled
    }
    
    func configure(
        spatialWidth: Float,
        reverbMix: Float,
        crossfeed: Float,
        crossfeedDelay: Float,
        bassGain: Float,
        dynamicRange: Bool,
        loudnessNorm: Bool
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        self.spatialWidth = spatialWidth
        self.reverbMix = reverbMix
        self.crossfeed = crossfeed
        self.crossfeedDelaySamples = Int(crossfeedDelay * sampleRate / 1000.0)
        self.bassGain = bassGain
        self.dynamicRangeEnabled = dynamicRange
        self.loudnessNormEnabled = loudnessNorm
        
        bassFilter?.setGain(bassGain)
    }
    
    func updateSampleRate(_ rate: Float) {
        lock.lock()
        defer { lock.unlock() }
        
        guard sampleRate != rate else { return }
        sampleRate = rate
        bassFilter = BiquadFilter(frequency: 100, gain: bassGain, q: 0.7, sampleRate: rate, type: .lowShelf)
        setupDelayBuffer()
        print("🎵 HiFi: Sample rate updated to \(rate) Hz")
    }

    
    /// 处理立体声音频缓冲区
    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        lock.lock()
        let enabled = isEnabled
        let width = spatialWidth
        let cf = crossfeed
        let cfDelay = crossfeedDelaySamples
        let bass = bassGain
        let dyn = dynamicRangeEnabled
        let loud = loudnessNormEnabled
        let filter = bassFilter
        lock.unlock()
        
        guard enabled, channelCount == 2 else { return }
        
        // 检查是否有任何效果需要处理
        let hasEffects = width > 0 || cf > 0 || bass > 0 || dyn || loud
        guard hasEffects else { return }
        
        for i in 0..<frameCount {
            let leftIdx = i * 2
            let rightIdx = i * 2 + 1
            
            var left = buffer[leftIdx]
            var right = buffer[rightIdx]
            
            // 1. 空间音效 (Stereo Widening) - 增强效果
            if width > 0 {
                let mid = (left + right) * 0.5
                let side = (left - right) * 0.5
                // 增强立体声宽度效果
                let wideSide = side * (1.0 + width * 2.0)
                left = mid + wideSide
                right = mid - wideSide
            }
            
            // 2. 3D 环绕 (Crossfeed) - 修复延迟缓冲区问题
            if cf > 0 {
                // 确保延迟缓冲区有效
                if delayBufferL.count > 0 {
                    let actualDelay = min(cfDelay, delayBufferL.count - 1)
                    if actualDelay > 0 {
                        let readIndex = (delayIndex + delayBufferL.count - actualDelay) % delayBufferL.count
                        let delayedL = delayBufferL[readIndex]
                        let delayedR = delayBufferR[readIndex]
                        
                        delayBufferL[delayIndex] = left
                        delayBufferR[delayIndex] = right
                        delayIndex = (delayIndex + 1) % delayBufferL.count
                        
                        // 交叉馈送 - 增强效果
                        let crossAmount = cf * 0.6
                        left = left * (1 - crossAmount) + delayedR * crossAmount
                        right = right * (1 - crossAmount) + delayedL * crossAmount
                    }
                }
            }
            
            // 3. 低音增强 - 使用滤波器增强低频
            if bass > 0, let bassFilter = filter {
                // 提取低频成分并增强
                let bassL = bassFilter.process(left, channel: 0)
                let bassR = bassFilter.process(right, channel: 1)
                
                // 将增强的低频混合回原信号
                let boostAmount = bass / 12.0  // 0-1 范围
                left = left + bassL * boostAmount
                right = right + bassR * boostAmount
            }
            
            // 4. 动态范围压缩
            if dyn {
                let peak = max(abs(left), abs(right))
                let threshold: Float = 0.5  // 降低阈值使效果更明显
                let ratio: Float = 3.0
                
                if peak > threshold {
                    let overThreshold = peak - threshold
                    let compressed = threshold + overThreshold / ratio
                    let targetGain = peak > 0.001 ? compressed / peak : 1.0
                    
                    // 平滑增益变化
                    let coef: Float = targetGain < compressorGain ? 0.01 : 0.001
                    compressorGain = compressorGain + coef * (targetGain - compressorGain)
                } else {
                    compressorGain = compressorGain + 0.001 * (1.0 - compressorGain)
                }
                
                left *= compressorGain
                right *= compressorGain
            }
            
            // 5. 响度均衡
            if loud {
                let targetRMS: Float = 0.25
                let currentRMS = sqrt((left * left + right * right) * 0.5)
                loudnessRMS = loudnessRMS * 0.995 + currentRMS * 0.005
                
                if loudnessRMS > 0.001 {
                    let targetGain = targetRMS / loudnessRMS
                    let clampedGain = min(max(targetGain, 0.5), 2.5)
                    loudnessGain = loudnessGain + 0.001 * (clampedGain - loudnessGain)
                    left *= loudnessGain
                    right *= loudnessGain
                }
            }
            
            // 软限幅 - 防止削波
            left = tanh(left * 0.9) / 0.9
            right = tanh(right * 0.9) / 0.9
            
            buffer[leftIdx] = left
            buffer[rightIdx] = right
        }
    }
}
