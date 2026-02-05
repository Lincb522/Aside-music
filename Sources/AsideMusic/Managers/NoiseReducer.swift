//
//  NoiseReducer.swift
//  AsideMusic
//
//  智能降噪引擎 - 基于频谱门限的噪声抑制
//

import AVFoundation
import Accelerate

/// 降噪模式
enum NoiseReductionMode: String, CaseIterable, Identifiable, Codable {
    case off = "关闭"
    case light = "轻度"
    case moderate = "中度"
    case strong = "强力"
    case adaptive = "自适应"
    
    var id: String { rawValue }
    
    /// 降噪强度 (0-1)
    var strength: Float {
        switch self {
        case .off: return 0
        case .light: return 0.3
        case .moderate: return 0.5
        case .strong: return 0.8
        case .adaptive: return 0.5
        }
    }
    
    /// 过度减法因子
    var overSubtraction: Float {
        switch self {
        case .off: return 1.0
        case .light: return 1.5
        case .moderate: return 2.0
        case .strong: return 3.0
        case .adaptive: return 2.0
        }
    }
    
    /// 频谱下限因子
    var spectralFloor: Float {
        switch self {
        case .off: return 0
        case .light: return 0.1
        case .moderate: return 0.05
        case .strong: return 0.02
        case .adaptive: return 0.05
        }
    }
}

/// 智能降噪处理器
final class NoiseReducer {
    
    // FFT 设置
    private let fftSize: Int = 1024
    private var fftSetup: vDSP_DFT_Setup?
    private var ifftSetup: vDSP_DFT_Setup?
    
    // 工作缓冲区 - 左右声道分开
    private var inputBufferL: [Float]
    private var inputBufferR: [Float]
    private var outputBufferL: [Float]
    private var outputBufferR: [Float]
    private var overlapBufferL: [Float]
    private var overlapBufferR: [Float]
    private var windowBuffer: [Float]
    
    // FFT 缓冲区
    private var realIn: [Float]
    private var imagIn: [Float]
    private var realOut: [Float]
    private var imagOut: [Float]
    private var magnitudes: [Float]
    private var phases: [Float]
    private var processedMagnitudes: [Float]
    
    // 噪声估计 (左右声道)
    private var noiseSpectrumL: [Float]
    private var noiseSpectrumR: [Float]
    private var noiseUpdateFrames: Int = 0
    private let noiseLearnFrames: Int = 20
    private var isLearningNoise: Bool = true
    
    // 平滑处理
    private var prevMagnitudesL: [Float]
    private var prevMagnitudesR: [Float]
    private let smoothingFactor: Float = 0.3
    
    // 参数
    private var mode: NoiseReductionMode = .off
    private var strength: Float = 0
    private var isEnabled: Bool = false
    
    // 缓冲区索引
    private var bufferIndexL: Int = 0
    private var bufferIndexR: Int = 0
    private let hopSize: Int
    
    private let lock = NSLock()
    
    init() {
        hopSize = fftSize / 4
        
        inputBufferL = [Float](repeating: 0, count: fftSize)
        inputBufferR = [Float](repeating: 0, count: fftSize)
        outputBufferL = [Float](repeating: 0, count: fftSize)
        outputBufferR = [Float](repeating: 0, count: fftSize)
        overlapBufferL = [Float](repeating: 0, count: fftSize)
        overlapBufferR = [Float](repeating: 0, count: fftSize)
        windowBuffer = [Float](repeating: 0, count: fftSize)
        
        realIn = [Float](repeating: 0, count: fftSize)
        imagIn = [Float](repeating: 0, count: fftSize)
        realOut = [Float](repeating: 0, count: fftSize)
        imagOut = [Float](repeating: 0, count: fftSize)
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
        phases = [Float](repeating: 0, count: fftSize / 2)
        processedMagnitudes = [Float](repeating: 0, count: fftSize / 2)
        
        noiseSpectrumL = [Float](repeating: 0, count: fftSize / 2)
        noiseSpectrumR = [Float](repeating: 0, count: fftSize / 2)
        prevMagnitudesL = [Float](repeating: 0, count: fftSize / 2)
        prevMagnitudesR = [Float](repeating: 0, count: fftSize / 2)
        
        // Hann 窗
        vDSP_hann_window(&windowBuffer, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        // FFT 设置
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        ifftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .INVERSE)
    }
    
    deinit {
        if let setup = fftSetup { vDSP_DFT_DestroySetup(setup) }
        if let setup = ifftSetup { vDSP_DFT_DestroySetup(setup) }
    }
    
    // MARK: - Public Methods
    
    func setMode(_ newMode: NoiseReductionMode) {
        lock.lock()
        defer { lock.unlock() }
        mode = newMode
        strength = newMode.strength
        
        // 切换模式时重新学习噪声
        if newMode != .off {
            resetNoiseLearning()
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        isEnabled = enabled
        
        if enabled {
            resetNoiseLearning()
        }
    }
    
    func resetNoiseLearning() {
        noiseUpdateFrames = 0
        isLearningNoise = true
        noiseSpectrumL = [Float](repeating: 0, count: fftSize / 2)
        noiseSpectrumR = [Float](repeating: 0, count: fftSize / 2)
    }
    
    /// 处理立体声音频
    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        lock.lock()
        let enabled = isEnabled
        let currentMode = mode
        lock.unlock()
        
        // 如果禁用或模式为关闭，直接返回不做任何处理
        guard enabled, currentMode != .off, channelCount == 2 else { return }
        
        // 降噪处理暂时简化为直通，避免影响其他功能
        // TODO: 完善降噪算法
    }
    
    // MARK: - Private Methods
    
    private func processFrame(
        inputBuffer: inout [Float],
        outputBuffer: inout [Float],
        overlapBuffer: inout [Float],
        noiseSpectrum: inout [Float],
        prevMagnitudes: inout [Float],
        mode: NoiseReductionMode,
        strength: Float
    ) {
        guard let fftSetup = fftSetup, let ifftSetup = ifftSetup else { return }
        
        // 1. 应用窗函数
        var windowedInput = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(inputBuffer, 1, windowBuffer, 1, &windowedInput, 1, vDSP_Length(fftSize))
        
        // 2. 准备 FFT 输入
        for i in 0..<fftSize {
            realIn[i] = windowedInput[i]
            imagIn[i] = 0
        }
        
        // 3. 执行 FFT
        vDSP_DFT_Execute(fftSetup, &realIn, &imagIn, &realOut, &imagOut)
        
        // 4. 计算幅度和相位
        for i in 0..<(fftSize / 2) {
            let real = realOut[i]
            let imag = imagOut[i]
            magnitudes[i] = sqrt(real * real + imag * imag)
            phases[i] = atan2(imag, real)
        }
        
        // 5. 噪声学习阶段
        if isLearningNoise && noiseUpdateFrames < noiseLearnFrames {
            for i in 0..<(fftSize / 2) {
                // 使用最小值跟踪估计噪声
                if noiseUpdateFrames == 0 {
                    noiseSpectrum[i] = magnitudes[i]
                } else {
                    noiseSpectrum[i] = min(noiseSpectrum[i], magnitudes[i])
                }
            }
            noiseUpdateFrames += 1
            
            if noiseUpdateFrames >= noiseLearnFrames {
                isLearningNoise = false
                // 稍微放大噪声估计以确保有效降噪
                var scale: Float = 1.2
                vDSP_vsmul(noiseSpectrum, 1, &scale, &noiseSpectrum, 1, vDSP_Length(fftSize / 2))
            }
            
            // 学习阶段不处理，直接输出
            processedMagnitudes = magnitudes
        } else {
            // 6. 频谱减法降噪
            let overSub = mode.overSubtraction * strength
            let floor = mode.spectralFloor
            
            for i in 0..<(fftSize / 2) {
                // 自适应模式：根据信噪比调整
                var localStrength = strength
                if mode == .adaptive {
                    let snr = magnitudes[i] / max(noiseSpectrum[i], 0.0001)
                    // SNR 低时增强降噪，SNR 高时减弱
                    localStrength = min(1.0, max(0.1, 1.0 / snr))
                }
                
                // 频谱减法
                let noiseEstimate = noiseSpectrum[i] * overSub * localStrength
                var cleanMag = magnitudes[i] - noiseEstimate
                
                // 频谱下限
                let minMag = magnitudes[i] * floor
                cleanMag = max(cleanMag, minMag)
                
                // 平滑处理减少音乐噪声
                processedMagnitudes[i] = prevMagnitudes[i] * smoothingFactor + cleanMag * (1 - smoothingFactor)
                prevMagnitudes[i] = processedMagnitudes[i]
            }
        }
        
        // 7. 重建频谱
        for i in 0..<(fftSize / 2) {
            realIn[i] = processedMagnitudes[i] * cos(phases[i])
            imagIn[i] = processedMagnitudes[i] * sin(phases[i])
        }
        // 镜像
        for i in (fftSize / 2)..<fftSize {
            realIn[i] = realIn[fftSize - i]
            imagIn[i] = -imagIn[fftSize - i]
        }
        
        // 8. 执行 IFFT
        vDSP_DFT_Execute(ifftSetup, &realIn, &imagIn, &realOut, &imagOut)
        
        // 9. 归一化
        var scale = 1.0 / Float(fftSize)
        vDSP_vsmul(realOut, 1, &scale, &outputBuffer, 1, vDSP_Length(fftSize))
        
        // 10. 应用窗函数
        vDSP_vmul(outputBuffer, 1, windowBuffer, 1, &outputBuffer, 1, vDSP_Length(fftSize))
        
        // 11. 重叠相加
        vDSP_vadd(overlapBuffer, 1, outputBuffer, 1, &overlapBuffer, 1, vDSP_Length(fftSize))
        
        // 12. 移动重叠缓冲区
        for i in 0..<(fftSize - hopSize) {
            overlapBuffer[i] = overlapBuffer[i + hopSize]
        }
        for i in (fftSize - hopSize)..<fftSize {
            overlapBuffer[i] = 0
        }
    }
}
