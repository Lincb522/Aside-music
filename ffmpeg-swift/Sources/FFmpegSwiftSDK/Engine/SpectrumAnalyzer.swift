// SpectrumAnalyzer.swift
// FFmpegSwiftSDK
//
// 实时 FFT 频谱分析器。从 AudioRenderer 的输出中提取频率数据，
// 供 UI 层绘制频谱柱状图或波形动画。
// 使用 vDSP 加速 FFT 计算。

import Foundation
import Accelerate

/// 频谱数据回调。magnitudes 数组长度 = bandCount，值范围 [0, 1]。
public typealias SpectrumCallback = (_ magnitudes: [Float]) -> Void

/// 实时 FFT 频谱分析器。
///
/// 从音频渲染回调中采集 PCM 数据，执行 FFT 变换，
/// 输出归一化的频率幅度数据供 UI 可视化。
///
/// 通过 `StreamPlayer.spectrumAnalyzer` 访问：
/// ```swift
/// player.spectrumAnalyzer.onSpectrum = { magnitudes in
///     // magnitudes: [Float]，长度 = bandCount
///     // 在主线程更新 UI
/// }
/// player.spectrumAnalyzer.isEnabled = true
/// ```
public final class SpectrumAnalyzer {

    // MARK: - 配置

    /// FFT 窗口大小（必须是 2 的幂）。越大频率分辨率越高，但延迟越大。
    public let fftSize: Int

    /// 输出频段数量（将 FFT bin 合并为指定数量的频段）。
    public let bandCount: Int

    /// 是否启用频谱分析。关闭时不消耗 CPU。
    public var isEnabled: Bool = false

    /// 频谱数据回调。在音频线程调用，UI 更新需自行 dispatch 到主线程。
    public var onSpectrum: SpectrumCallback?

    /// 平滑系数（0~1）。越大越平滑，但响应越慢。
    public var smoothing: Float = 0.7

    // MARK: - 内部状态

    /// vDSP FFT 设置
    private let fftSetup: FFTSetup

    /// log2(fftSize)
    private let log2n: vDSP_Length

    /// 汉宁窗
    private let window: [Float]

    /// 输入采样缓冲区（环形写入）
    private var inputBuffer: [Float]
    private var writeIndex: Int = 0
    private var samplesCollected: Int = 0

    /// 上一帧的频谱值（用于平滑）
    private var previousMagnitudes: [Float]

    /// 临时缓冲区
    private var realPart: [Float]
    private var imagPart: [Float]

    // MARK: - 初始化

    /// 创建频谱分析器。
    /// - Parameters:
    ///   - fftSize: FFT 窗口大小，默认 2048。
    ///   - bandCount: 输出频段数，默认 64。
    public init(fftSize: Int = 2048, bandCount: Int = 64) {
        self.fftSize = fftSize
        self.bandCount = bandCount
        self.log2n = vDSP_Length(log2(Double(fftSize)))

        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        // 汉宁窗
        var win = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&win, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = win

        self.inputBuffer = [Float](repeating: 0, count: fftSize)
        self.previousMagnitudes = [Float](repeating: 0, count: bandCount)
        self.realPart = [Float](repeating: 0, count: fftSize / 2)
        self.imagPart = [Float](repeating: 0, count: fftSize / 2)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - 数据输入（从 AudioRenderer 调用）

    /// 输入 PCM 采样数据。在音频渲染线程调用。
    /// 自动处理多声道（取第一声道或混合为单声道）。
    /// - Parameters:
    ///   - samples: interleaved Float32 PCM 数据指针
    ///   - frameCount: 帧数
    ///   - channelCount: 声道数
    func feed(samples: UnsafePointer<Float>, frameCount: Int, channelCount: Int) {
        guard isEnabled else { return }

        // 取左声道（或单声道）
        for i in 0..<frameCount {
            inputBuffer[writeIndex] = samples[i * channelCount]
            writeIndex = (writeIndex + 1) % fftSize
            samplesCollected += 1
        }

        // 收集够一个窗口就执行 FFT
        if samplesCollected >= fftSize {
            samplesCollected = 0
            performFFT()
        }
    }

    // MARK: - FFT 计算

    private func performFFT() {
        // 将环形缓冲区展开为连续数组，并应用窗函数
        var windowed = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            let idx = (writeIndex + i) % fftSize
            windowed[i] = inputBuffer[idx] * window[i]
        }

        // 拆分为实部和虚部（split complex），使用 withUnsafeMutableBufferPointer 确保指针生命周期安全
        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                windowed.withUnsafeBufferPointer { ptr in
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                        var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }
                }
            }
        }

        // 执行 FFT
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // 转换为 dB 并归一化
        let halfSize = Float(fftSize / 2)
        var scaledMags = magnitudes.map { sqrtf($0) / halfSize }

        // 合并 bin 到指定频段数（对数分布）
        let bands = mergeToBands(magnitudes: &scaledMags)

        // 平滑
        var smoothed = [Float](repeating: 0, count: bandCount)
        for i in 0..<bandCount {
            smoothed[i] = smoothing * previousMagnitudes[i] + (1.0 - smoothing) * bands[i]
        }
        previousMagnitudes = smoothed

        // 回调
        onSpectrum?(smoothed)
    }

    /// 将线性 FFT bin 合并为对数分布的频段
    private func mergeToBands(magnitudes: inout [Float]) -> [Float] {
        let binCount = magnitudes.count
        var bands = [Float](repeating: 0, count: bandCount)

        for i in 0..<bandCount {
            // 对数分布：低频段覆盖少量 bin，高频段覆盖大量 bin
            let startRatio = pow(Float(i) / Float(bandCount), 2.0)
            let endRatio = pow(Float(i + 1) / Float(bandCount), 2.0)
            let startBin = Int(startRatio * Float(binCount))
            let endBin = min(Int(endRatio * Float(binCount)), binCount)

            if endBin > startBin {
                var sum: Float = 0
                for j in startBin..<endBin {
                    sum += magnitudes[j]
                }
                bands[i] = sum / Float(endBin - startBin)
            }
        }

        // 归一化到 [0, 1]
        let maxVal = bands.max() ?? 1.0
        if maxVal > 0 {
            for i in 0..<bandCount {
                bands[i] = min(bands[i] / maxVal, 1.0)
            }
        }

        return bands
    }
}
