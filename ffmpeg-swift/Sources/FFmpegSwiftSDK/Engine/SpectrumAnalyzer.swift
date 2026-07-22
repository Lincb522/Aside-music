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

/// Independent pre-effect PCM analysis callback. Samples are copied from the
/// renderer before AudioFilterGraph, EQFilter, and repair processing.
public typealias PCMAnalysisCallback = @Sendable (
    _ leftSamples: [Float],
    _ rightSamples: [Float]?,
    _ sampleRate: Double
) -> Void

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

    private struct AnalysisObserverEntry {
        let callback: @Sendable ([Float], Double, Float) -> Void
        var minimumInterval: TimeInterval
        var lastDeliveryUptime: TimeInterval = 0
    }

    private struct PCMObserverEntry {
        let callback: PCMAnalysisCallback
        var minimumInterval: TimeInterval
        var lastDeliveryUptime: TimeInterval = 0
    }

    // MARK: - 配置

    /// FFT 窗口大小（必须是 2 的幂）。越大频率分辨率越高，但延迟越大。
    public let fftSize: Int

    /// 输出频段数量（将 FFT bin 合并为指定数量的频段）。
    public let bandCount: Int

    private let configurationLock = NSLock()
    private var storedIsEnabled = false
    private var storedCalibrationIsEnabled = false
    private var storedOnSpectrum: SpectrumCallback?
    private var storedOnRawSpectrum: ((_ magnitudes: [Float], _ sampleRate: Double, _ rms: Float) -> Void)?
    private var storedOnCalibrationSpectrum: ((_ linearMagnitudes: [Float], _ sampleRate: Double, _ rms: Float) -> Void)?
    private var analysisObservers: [UUID: AnalysisObserverEntry] = [:]
    private var pcmAnalysisObservers: [UUID: PCMObserverEntry] = [:]
    /// Smart calibration updates much more slowly than visual FFT. Throttling it
    /// at the analyzer prevents needless FFT work and MainActor task creation.
    private var calibrationMinimumInterval: TimeInterval = 1.0
    private var lastCalibrationDeliveryUptime: TimeInterval = 0
    private var storedSmoothing: Float = 0.7
    private var storedSampleRate: Double = 44100

    /// 是否启用频谱分析。关闭时不消耗 CPU。
    public var isEnabled: Bool {
        get { configurationLock.monoWithLock { storedIsEnabled } }
        set { configurationLock.monoWithLock { storedIsEnabled = newValue } }
    }

    /// Independent ownership flag for non-visual calibration consumers.
    /// A visualizer may turn `isEnabled` off without stopping intelligent EQ.
    public var isCalibrationEnabled: Bool {
        get { configurationLock.monoWithLock { storedCalibrationIsEnabled } }
        set {
            configurationLock.monoWithLock {
                if newValue, !storedCalibrationIsEnabled {
                    lastCalibrationDeliveryUptime = 0
                }
                storedCalibrationIsEnabled = newValue
            }
        }
    }

    var isActive: Bool {
        // AudioRenderer queries this from a realtime callback. Missing one
        // analysis window is always preferable to waiting behind UI/config work.
        guard configurationLock.try() else { return false }
        let visualActive = storedIsEnabled
            && (storedOnSpectrum != nil || storedOnRawSpectrum != nil)
        let calibrationActive = storedCalibrationIsEnabled
            && storedOnCalibrationSpectrum != nil
        let active = visualActive || calibrationActive
            || !analysisObservers.isEmpty || !pcmAnalysisObservers.isEmpty
        configurationLock.unlock()
        return active
    }

    /// 频谱数据回调。在专用分析队列调用，UI 更新需自行 dispatch 到主线程。
    public var onSpectrum: SpectrumCallback? {
        get { configurationLock.monoWithLock { storedOnSpectrum } }
        set { configurationLock.monoWithLock { storedOnSpectrum = newValue } }
    }

    /// 原始频谱回调（模拟 WebAudio AnalyserNode.getByteFrequencyData / 255）。
    /// magnitudes: 长度 = fftSize/2 的线性 bin，值域 [0,1]（dB 归一化，minDb=-100, maxDb=-30，
    /// 含 WebAudio 默认 smoothingTimeConstant=0.8 的幅度平滑）。
    /// sampleRate: 当前音频采样率；rms: 时域 RMS（等价 getByteTimeDomainData 计算的 RMS）。
    /// 在专用分析队列调用。
    public var onRawSpectrum: ((_ magnitudes: [Float], _ sampleRate: Double, _ rms: Float) -> Void)? {
        get { configurationLock.monoWithLock { storedOnRawSpectrum } }
        set { configurationLock.monoWithLock { storedOnRawSpectrum = newValue } }
    }

    /// Dedicated non-visual analysis stream for slow output calibration.
    /// This does not replace `onSpectrum` or `onRawSpectrum`, so visualizers and
    /// intelligent EQ can run at the same time.
    public var onCalibrationSpectrum: ((_ linearMagnitudes: [Float], _ sampleRate: Double, _ rms: Float) -> Void)? {
        get { configurationLock.monoWithLock { storedOnCalibrationSpectrum } }
        set {
            configurationLock.monoWithLock {
                storedOnCalibrationSpectrum = newValue
                lastCalibrationDeliveryUptime = 0
            }
        }
    }

    /// Adds an independent analysis consumer without replacing visualizer or
    /// calibration callbacks. The returned token must be removed when sampling
    /// finishes so the FFT pipeline can return to its previous power state.
    @discardableResult
    public func addAnalysisObserver(
        minimumInterval: TimeInterval = 0,
        _ observer: @escaping @Sendable (_ linearMagnitudes: [Float], _ sampleRate: Double, _ rms: Float) -> Void
    ) -> UUID {
        let token = UUID()
        configurationLock.monoWithLock {
            analysisObservers[token] = AnalysisObserverEntry(
                callback: observer,
                minimumInterval: max(0, minimumInterval)
            )
        }
        return token
    }

    public func setAnalysisObserverMinimumInterval(_ interval: TimeInterval, for token: UUID) {
        configurationLock.monoWithLock {
            guard var entry = analysisObservers[token] else { return }
            entry.minimumInterval = max(0, interval)
            analysisObservers[token] = entry
        }
    }

    public func removeAnalysisObserver(_ token: UUID) {
        configurationLock.monoWithLock {
            analysisObservers.removeValue(forKey: token)
        }
    }

    /// Adds an independent PCM consumer without replacing spectrum callbacks.
    /// The callback runs on SpectrumAnalyzer's analysis queue, never the audio
    /// render thread. Remove the token when sampling finishes.
    @discardableResult
    public func addPCMAnalysisObserver(
        minimumInterval: TimeInterval = 0,
        _ observer: @escaping PCMAnalysisCallback
    ) -> UUID {
        let token = UUID()
        configurationLock.monoWithLock {
            pcmAnalysisObservers[token] = PCMObserverEntry(
                callback: observer,
                minimumInterval: max(0, minimumInterval)
            )
        }
        return token
    }

    public func setPCMAnalysisObserverMinimumInterval(_ interval: TimeInterval, for token: UUID) {
        configurationLock.monoWithLock {
            guard var entry = pcmAnalysisObservers[token] else { return }
            entry.minimumInterval = max(0, interval)
            pcmAnalysisObservers[token] = entry
        }
    }

    public func removePCMAnalysisObserver(_ token: UUID) {
        configurationLock.monoWithLock {
            pcmAnalysisObservers.removeValue(forKey: token)
        }
    }

    /// 平滑系数（0~1）。越大越平滑，但响应越慢。
    public var smoothing: Float {
        get { configurationLock.monoWithLock { storedSmoothing } }
        set { configurationLock.monoWithLock { storedSmoothing = min(max(newValue, 0), 1) } }
    }

    /// 当前采样率（由 feed 更新）
    public var sampleRate: Double {
        configurationLock.monoWithLock { storedSampleRate }
    }

    // MARK: - 内部状态

    /// vDSP FFT 设置
    private let fftSetup: FFTSetup

    /// log2(fftSize)
    private let log2n: vDSP_Length

    /// 汉宁窗
    private let window: [Float]

    /// 输入采样缓冲区（环形写入）
    private var inputBuffer: [Float]
    private var inputRightBuffer: [Float]
    private var writeIndex: Int = 0
    private var samplesCollected: Int = 0

    /// The audio callback only copies into a preallocated handoff buffer and
    /// signals this source. FFT work and callback array creation happen off RT.
    private let collectionLock = NSLock()
    private let analysisQueue = DispatchQueue(
        label: "com.ffmpeg-sdk.spectrum-analysis",
        qos: .utility,
        autoreleaseFrequency: .workItem
    )
    private var analysisSource: DispatchSourceUserDataAdd!
    private var processingWindow: [Float]
    private var processingRightWindow: [Float]
    private var pendingSampleRate: Double = 44100
    private var pendingHasStereo = false
    private var hasPendingWindow = false

    /// 上一帧的频谱值（用于平滑）
    private var previousMagnitudes: [Float]

    /// WebAudio 风格幅度平滑的上一帧线性幅度（长度 = fftSize/2）
    private var previousRawAmplitudes: [Float]

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
        self.inputRightBuffer = [Float](repeating: 0, count: fftSize)
        self.processingWindow = [Float](repeating: 0, count: fftSize)
        self.processingRightWindow = [Float](repeating: 0, count: fftSize)
        self.previousMagnitudes = [Float](repeating: 0, count: bandCount)
        self.previousRawAmplitudes = [Float](repeating: 0, count: fftSize / 2)
        self.realPart = [Float](repeating: 0, count: fftSize / 2)
        self.imagPart = [Float](repeating: 0, count: fftSize / 2)

        let source = DispatchSource.makeUserDataAddSource(queue: analysisQueue)
        self.analysisSource = source
        source.setEventHandler { [weak self] in
            self?.consumePendingWindow()
        }
        source.resume()
    }

    deinit {
        analysisSource?.setEventHandler {}
        analysisSource?.cancel()
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - 数据输入（从 AudioRenderer 调用）

    /// 输入 PCM 采样数据。在音频渲染线程调用。
    /// 自动处理多声道（取第一声道或混合为单声道）。
    /// - Parameters:
    ///   - samples: interleaved Float32 PCM 数据指针
    ///   - frameCount: 帧数
    ///   - channelCount: 声道数
    func feed(samples: UnsafePointer<Float>, frameCount: Int, channelCount: Int, sampleRate: Double = 44100) {
        guard configurationLock.try() else { return }
        // Independent observers are analysis owners too. Previously the outer
        // renderer saw `isActive == true`, but feed discarded the same buffer
        // unless a visualizer or calibration happened to be enabled.
        let visualActive = storedIsEnabled
            && (storedOnSpectrum != nil || storedOnRawSpectrum != nil)
        // Agent observers are temporary and need dense source windows for an
        // accurate 30-second measurement. Keep their collection continuous;
        // only the always-on smart calibration is cadence-gated here.
        let transientAnalysisActive = !analysisObservers.isEmpty
            || !pcmAnalysisObservers.isEmpty
        let uptime = visualActive || transientAnalysisActive
            ? 0
            : ProcessInfo.processInfo.systemUptime
        let calibrationDue = storedCalibrationIsEnabled
            && storedOnCalibrationSpectrum != nil
            && (lastCalibrationDeliveryUptime == 0
                || uptime - lastCalibrationDeliveryUptime >= calibrationMinimumInterval)
        let enabled = visualActive || transientAnalysisActive || calibrationDue
        configurationLock.unlock()
        guard enabled, channelCount > 0 else { return }

        // Never block the audio callback behind the analysis worker. Dropping an
        // FFT window is preferable to delaying hardware rendering.
        guard collectionLock.try() else { return }
        defer { collectionLock.unlock() }

        // Keep the first stereo pair for phase and spatial analysis. The FFT
        // path remains left-channel based for compatibility with visualizers.
        for i in 0..<frameCount {
            let sampleIndex = i * channelCount
            let left = samples[sampleIndex]
            inputBuffer[writeIndex] = left
            inputRightBuffer[writeIndex] = channelCount > 1
                ? samples[sampleIndex + 1]
                : left
            writeIndex = (writeIndex + 1) % fftSize
            samplesCollected += 1
        }

        // 收集够一个窗口就执行 FFT
        if samplesCollected >= fftSize {
            samplesCollected = 0
            guard !hasPendingWindow else { return }
            pendingSampleRate = sampleRate
            pendingHasStereo = channelCount > 1
            hasPendingWindow = true
            analysisSource.add(data: 1)
        }
    }

    private func consumePendingWindow() {
        let deliveryUptime = ProcessInfo.processInfo.systemUptime
        // Slow analysis observers do not need every 4096-sample window. Check
        // cadence before linearizing the ring buffer or running FFT so skipped
        // Agent frames cost only the non-blocking realtime handoff, not another
        // full analysis pass. Visual callbacks remain frame-continuous.
        guard hasDueConsumer(at: deliveryUptime) else {
            collectionLock.lock()
            hasPendingWindow = false
            collectionLock.unlock()
            return
        }

        collectionLock.lock()
        guard hasPendingWindow else {
            collectionLock.unlock()
            return
        }
        // Linearizing the ring buffer used to happen in `feed`, on the audio
        // render thread. Keep it here so analysis work can never extend an
        // AVAudioSourceNode callback.
        for index in 0..<fftSize {
            let sourceIndex = (writeIndex + index) % fftSize
            processingWindow[index] = inputBuffer[sourceIndex]
            processingRightWindow[index] = inputRightBuffer[sourceIndex]
        }
        let rate = pendingSampleRate
        let hasStereo = pendingHasStereo
        hasPendingWindow = false
        collectionLock.unlock()

        configurationLock.monoWithLock {
            storedSampleRate = rate
        }
        let pcmObservers = takeDuePCMObservers(at: deliveryUptime)
        if !pcmObservers.isEmpty {
            // Observer tasks may outlive this callback. Force independent
            // storage here, off the audio thread, so the reusable processing
            // buffers never trigger copy-on-write during the next render pass.
            let leftSnapshot = processingWindow.withUnsafeBufferPointer { Array($0) }
            let rightSnapshot = hasStereo
                ? processingRightWindow.withUnsafeBufferPointer { Array($0) }
                : nil
            for observer in pcmObservers {
                observer(leftSnapshot, rightSnapshot, rate)
            }
        }
        performFFT(
            samples: processingWindow,
            sampleRate: rate,
            deliveryUptime: deliveryUptime
        )
    }

    private func hasDueConsumer(at uptime: TimeInterval) -> Bool {
        configurationLock.monoWithLock {
            if storedIsEnabled,
               storedOnSpectrum != nil || storedOnRawSpectrum != nil {
                return true
            }
            if storedCalibrationIsEnabled,
               storedOnCalibrationSpectrum != nil,
               lastCalibrationDeliveryUptime == 0
                || uptime - lastCalibrationDeliveryUptime >= calibrationMinimumInterval {
                return true
            }
            if analysisObservers.values.contains(where: { entry in
                entry.lastDeliveryUptime == 0
                    || uptime - entry.lastDeliveryUptime >= entry.minimumInterval
            }) {
                return true
            }
            return pcmAnalysisObservers.values.contains(where: { entry in
                entry.lastDeliveryUptime == 0
                    || uptime - entry.lastDeliveryUptime >= entry.minimumInterval
            })
        }
    }

    private func takeDueAnalysisObservers(
        at uptime: TimeInterval
    ) -> [@Sendable ([Float], Double, Float) -> Void] {
        configurationLock.monoWithLock {
            var callbacks: [@Sendable ([Float], Double, Float) -> Void] = []
            for token in Array(analysisObservers.keys) {
                guard var entry = analysisObservers[token] else { continue }
                let isDue = entry.lastDeliveryUptime == 0
                    || uptime - entry.lastDeliveryUptime >= entry.minimumInterval
                guard isDue else { continue }
                entry.lastDeliveryUptime = uptime
                analysisObservers[token] = entry
                callbacks.append(entry.callback)
            }
            return callbacks
        }
    }

    private func takeDuePCMObservers(at uptime: TimeInterval) -> [PCMAnalysisCallback] {
        configurationLock.monoWithLock {
            var callbacks: [PCMAnalysisCallback] = []
            for token in Array(pcmAnalysisObservers.keys) {
                guard var entry = pcmAnalysisObservers[token] else { continue }
                let isDue = entry.lastDeliveryUptime == 0
                    || uptime - entry.lastDeliveryUptime >= entry.minimumInterval
                guard isDue else { continue }
                entry.lastDeliveryUptime = uptime
                pcmAnalysisObservers[token] = entry
                callbacks.append(entry.callback)
            }
            return callbacks
        }
    }

    private func takeDueCalibrationObserver(
        at uptime: TimeInterval
    ) -> ((_ linearMagnitudes: [Float], _ sampleRate: Double, _ rms: Float) -> Void)? {
        configurationLock.monoWithLock {
            guard storedCalibrationIsEnabled,
                  let callback = storedOnCalibrationSpectrum else { return nil }
            let isDue = lastCalibrationDeliveryUptime == 0
                || uptime - lastCalibrationDeliveryUptime >= calibrationMinimumInterval
            guard isDue else { return nil }
            lastCalibrationDeliveryUptime = uptime
            return callback
        }
    }

    // MARK: - FFT 计算

    private func performFFT(
        samples: [Float],
        sampleRate: Double,
        deliveryUptime: TimeInterval
    ) {
        let analysisCallbacks = takeDueAnalysisObservers(at: deliveryUptime)
        let calibrationCallback = takeDueCalibrationObserver(at: deliveryUptime)
        let callbacks = configurationLock.monoWithLock {
            (
                storedOnRawSpectrum,
                storedOnSpectrum,
                storedSmoothing
            )
        }
        guard callbacks.0 != nil
                || callbacks.1 != nil
                || calibrationCallback != nil
                || !analysisCallbacks.isEmpty else {
            return
        }

        // 应用窗函数。所有分配都发生在专用分析队列。
        var windowed = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            windowed[i] = samples[i] * window[i]
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

        // 原始频谱输出：复刻 WebAudio getByteFrequencyData 语义
        // 1) 线性幅度做 smoothingTimeConstant=0.8 平滑
        // 2) 转 dB 后按 [minDb=-100, maxDb=-30] 归一化到 [0,1]
        var timeDomainRMS: Float = 0
        if callbacks.0 != nil || calibrationCallback != nil || !analysisCallbacks.isEmpty {
            for sample in samples {
                let value = min(1, max(-1, sample))
                timeDomainRMS += value * value
            }
            timeDomainRMS = sqrtf(timeDomainRMS / Float(fftSize))
        }
        if let rawCallback = callbacks.0 {
            let tau: Float = 0.8
            let minDb: Float = -100
            let maxDb: Float = -30
            var rawBytes = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<(fftSize / 2) {
                let smoothedAmp = tau * previousRawAmplitudes[i] + (1 - tau) * scaledMags[i]
                previousRawAmplitudes[i] = smoothedAmp
                let db = 20 * log10f(max(smoothedAmp, 1e-10))
                rawBytes[i] = min(1, max(0, (db - minDb) / (maxDb - minDb)))
            }

            // 时域 RMS（等价 getByteTimeDomainData 的 RMS 计算）
            rawCallback(rawBytes, sampleRate, timeDomainRMS)
        }

        calibrationCallback?(scaledMags, sampleRate, timeDomainRMS)
        for observer in analysisCallbacks {
            observer(scaledMags, sampleRate, timeDomainRMS)
        }

        // Raw spectrum / calibration users do not need the logarithmic UI
        // bands. Avoid another merge, normalization and allocation unless a
        // visual band callback is actually attached.
        if let spectrumCallback = callbacks.1 {
            let bands = mergeToBands(magnitudes: &scaledMags)
            var smoothed = [Float](repeating: 0, count: bandCount)
            for i in 0..<bandCount {
                smoothed[i] = callbacks.2 * previousMagnitudes[i]
                    + (1.0 - callbacks.2) * bands[i]
            }
            previousMagnitudes = smoothed
            spectrumCallback(smoothed)
        }
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

private extension NSLock {
    func monoWithLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try operation()
    }
}
