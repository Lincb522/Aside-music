//
//  BiquadFilter.swift
//  AsideMusic
//
//  双二阶 IIR 滤波器 - 用于实现参数均衡器
//  支持峰值滤波器 (Peaking EQ) 类型
//

import Foundation
import Accelerate

/// 双二阶滤波器 (Biquad Filter)
/// 使用直接形式 II 转置结构实现
final class BiquadFilter {
    
    // MARK: - Filter Type
    
    enum FilterType {
        case peaking    // 峰值滤波器 (用于 EQ)
        case lowShelf   // 低频搁架 (用于低音增强)
        case highShelf  // 高频搁架
        case lowPass    // 低通
    }
    
    // MARK: - Filter Coefficients
    
    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0
    
    // MARK: - State Variables (per channel)
    
    private var z1: [Float] = [0, 0]  // 左右声道状态
    private var z2: [Float] = [0, 0]
    
    // MARK: - Parameters
    
    private(set) var frequency: Float
    private(set) var gain: Float
    private(set) var q: Float
    private(set) var sampleRate: Float
    private let filterType: FilterType
    
    // MARK: - Init
    
    init(frequency: Float, gain: Float = 0, q: Float = 1.41, sampleRate: Float = 44100, type: FilterType = .peaking) {
        self.frequency = frequency
        self.gain = gain
        self.q = q
        self.sampleRate = sampleRate
        self.filterType = type
        calculateCoefficients()
    }
    
    // MARK: - Public Methods
    
    /// 更新增益值
    func setGain(_ newGain: Float) {
        guard gain != newGain else { return }
        gain = newGain
        calculateCoefficients()
    }
    
    /// 更新采样率
    func setSampleRate(_ newRate: Float) {
        guard sampleRate != newRate else { return }
        sampleRate = newRate
        calculateCoefficients()
    }
    
    /// 重置滤波器状态
    func reset() {
        z1 = [0, 0]
        z2 = [0, 0]
    }
    
    /// 处理单个采样点 (单声道)
    func process(_ input: Float, channel: Int = 0) -> Float {
        let ch = min(channel, 1)
        
        // 直接形式 II 转置
        let output = b0 * input + z1[ch]
        z1[ch] = b1 * input - a1 * output + z2[ch]
        z2[ch] = b2 * input - a2 * output
        
        return output
    }
    
    /// 批量处理音频缓冲区 (立体声交错格式)
    func processBuffer(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        if channelCount == 1 {
            // 单声道
            for i in 0..<frameCount {
                buffer[i] = process(buffer[i], channel: 0)
            }
        } else {
            // 立体声 (交错格式: L R L R ...)
            for i in 0..<frameCount {
                let leftIdx = i * 2
                let rightIdx = i * 2 + 1
                buffer[leftIdx] = process(buffer[leftIdx], channel: 0)
                buffer[rightIdx] = process(buffer[rightIdx], channel: 1)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 计算滤波器系数
    private func calculateCoefficients() {
        switch filterType {
        case .peaking:
            calculatePeakingCoefficients()
        case .lowShelf:
            calculateLowShelfCoefficients()
        case .highShelf:
            calculateHighShelfCoefficients()
        case .lowPass:
            calculateLowPassCoefficients()
        }
    }
    
    /// 计算峰值滤波器系数 (Peaking EQ)
    private func calculatePeakingCoefficients() {
        // 如果增益为0，使用直通
        if abs(gain) < 0.001 {
            b0 = 1.0
            b1 = 0.0
            b2 = 0.0
            a1 = 0.0
            a2 = 0.0
            return
        }
        
        let A = powf(10, gain / 40.0)
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)
        
        let b0_raw = 1.0 + alpha * A
        let b1_raw = -2.0 * cosOmega
        let b2_raw = 1.0 - alpha * A
        let a0_raw = 1.0 + alpha / A
        let a1_raw = -2.0 * cosOmega
        let a2_raw = 1.0 - alpha / A
        
        b0 = b0_raw / a0_raw
        b1 = b1_raw / a0_raw
        b2 = b2_raw / a0_raw
        a1 = a1_raw / a0_raw
        a2 = a2_raw / a0_raw
    }
    
    /// 计算低频搁架滤波器系数
    private func calculateLowShelfCoefficients() {
        let A = powf(10, gain / 40.0)
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / 2.0 * sqrt((A + 1.0/A) * (1.0/q - 1.0) + 2.0)
        let sqrtA = sqrt(A)
        
        let b0_raw = A * ((A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha)
        let b1_raw = 2 * A * ((A - 1) - (A + 1) * cosOmega)
        let b2_raw = A * ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha)
        let a0_raw = (A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha
        let a1_raw = -2 * ((A - 1) + (A + 1) * cosOmega)
        let a2_raw = (A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha
        
        b0 = b0_raw / a0_raw
        b1 = b1_raw / a0_raw
        b2 = b2_raw / a0_raw
        a1 = a1_raw / a0_raw
        a2 = a2_raw / a0_raw
    }
    
    /// 计算高频搁架滤波器系数
    private func calculateHighShelfCoefficients() {
        let A = powf(10, gain / 40.0)
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / 2.0 * sqrt((A + 1.0/A) * (1.0/q - 1.0) + 2.0)
        let sqrtA = sqrt(A)
        
        let b0_raw = A * ((A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha)
        let b1_raw = -2 * A * ((A - 1) + (A + 1) * cosOmega)
        let b2_raw = A * ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha)
        let a0_raw = (A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha
        let a1_raw = 2 * ((A - 1) - (A + 1) * cosOmega)
        let a2_raw = (A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha
        
        b0 = b0_raw / a0_raw
        b1 = b1_raw / a0_raw
        b2 = b2_raw / a0_raw
        a1 = a1_raw / a0_raw
        a2 = a2_raw / a0_raw
    }
    
    /// 计算低通滤波器系数
    private func calculateLowPassCoefficients() {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)
        
        let b0_raw = (1 - cosOmega) / 2
        let b1_raw = 1 - cosOmega
        let b2_raw = (1 - cosOmega) / 2
        let a0_raw = 1 + alpha
        let a1_raw = -2 * cosOmega
        let a2_raw = 1 - alpha
        
        b0 = b0_raw / a0_raw
        b1 = b1_raw / a0_raw
        b2 = b2_raw / a0_raw
        a1 = a1_raw / a0_raw
        a2 = a2_raw / a0_raw
    }
}

// MARK: - Filter Bank

/// 滤波器组 - 管理多个频段的滤波器
final class FilterBank {
    
    private var filters: [BiquadFilter] = []
    private let frequencies: [Float]
    private var gains: [Float]
    private let q: Float
    private var sampleRate: Float
    
    init(frequencies: [Float], gains: [Float], q: Float = 1.41, sampleRate: Float = 44100) {
        self.frequencies = frequencies
        self.gains = gains
        self.q = q
        self.sampleRate = sampleRate
        
        // 创建滤波器
        for (freq, gain) in zip(frequencies, gains) {
            filters.append(BiquadFilter(frequency: freq, gain: gain, q: q, sampleRate: sampleRate))
        }
    }
    
    /// 更新所有频段增益
    func updateGains(_ newGains: [Float]) {
        guard newGains.count == filters.count else { return }
        gains = newGains
        for (i, gain) in newGains.enumerated() {
            filters[i].setGain(gain)
        }
    }
    
    /// 更新采样率
    func updateSampleRate(_ newRate: Float) {
        guard sampleRate != newRate else { return }
        sampleRate = newRate
        for filter in filters {
            filter.setSampleRate(newRate)
        }
    }
    
    /// 重置所有滤波器状态
    func reset() {
        for filter in filters {
            filter.reset()
        }
    }
    
    /// 处理音频缓冲区 (级联所有滤波器)
    func processBuffer(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        for filter in filters {
            filter.processBuffer(buffer, frameCount: frameCount, channelCount: channelCount)
        }
    }
}
