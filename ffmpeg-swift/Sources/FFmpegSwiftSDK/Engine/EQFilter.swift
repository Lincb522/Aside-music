// EQFilter.swift
// FFmpegSwiftSDK
//
// Mono realtime equalizer and calibration stage. The processor owns the
// graphic, parametric and dynamics filters so interactive changes never need
// to rebuild the FFmpeg filter graph.

import Foundation

// MARK: - Biquad

struct BiquadCoefficients {
    var b0: Float
    var b1: Float
    var b2: Float
    var a1: Float
    var a2: Float

    static let unity = BiquadCoefficients(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0)

    static func peakingEQ(gainDB: Float, centerFrequency: Float, sampleRate: Float, q: Float = 1) -> Self {
        let a = powf(10, gainDB / 40)
        let w0 = normalizedAngularFrequency(centerFrequency, sampleRate: sampleRate)
        let alpha = sinf(w0) / (2 * max(q, 0.1))
        let cosW0 = cosf(w0)
        return normalized(
            b0: 1 + alpha * a,
            b1: -2 * cosW0,
            b2: 1 - alpha * a,
            a0: 1 + alpha / a,
            a1: -2 * cosW0,
            a2: 1 - alpha / a
        )
    }

    static func lowShelf(gainDB: Float, frequency: Float, sampleRate: Float) -> Self {
        let a = powf(10, gainDB / 40)
        let w0 = normalizedAngularFrequency(frequency, sampleRate: sampleRate)
        let cosW0 = cosf(w0)
        let alpha = sinf(w0) * sqrtf(2) / 2
        let beta = 2 * sqrtf(a) * alpha
        return normalized(
            b0: a * ((a + 1) - (a - 1) * cosW0 + beta),
            b1: 2 * a * ((a - 1) - (a + 1) * cosW0),
            b2: a * ((a + 1) - (a - 1) * cosW0 - beta),
            a0: (a + 1) + (a - 1) * cosW0 + beta,
            a1: -2 * ((a - 1) + (a + 1) * cosW0),
            a2: (a + 1) + (a - 1) * cosW0 - beta
        )
    }

    static func highShelf(gainDB: Float, frequency: Float, sampleRate: Float) -> Self {
        let a = powf(10, gainDB / 40)
        let w0 = normalizedAngularFrequency(frequency, sampleRate: sampleRate)
        let cosW0 = cosf(w0)
        let alpha = sinf(w0) * sqrtf(2) / 2
        let beta = 2 * sqrtf(a) * alpha
        return normalized(
            b0: a * ((a + 1) + (a - 1) * cosW0 + beta),
            b1: -2 * a * ((a - 1) + (a + 1) * cosW0),
            b2: a * ((a + 1) + (a - 1) * cosW0 - beta),
            a0: (a + 1) - (a - 1) * cosW0 + beta,
            a1: 2 * ((a - 1) - (a + 1) * cosW0),
            a2: (a + 1) - (a - 1) * cosW0 - beta
        )
    }

    static func lowPass(frequency: Float, sampleRate: Float, q: Float) -> Self {
        let w0 = normalizedAngularFrequency(frequency, sampleRate: sampleRate)
        let cosW0 = cosf(w0)
        let alpha = sinf(w0) / (2 * max(q, 0.1))
        return normalized(
            b0: (1 - cosW0) / 2,
            b1: 1 - cosW0,
            b2: (1 - cosW0) / 2,
            a0: 1 + alpha,
            a1: -2 * cosW0,
            a2: 1 - alpha
        )
    }

    static func highPass(frequency: Float, sampleRate: Float, q: Float) -> Self {
        let w0 = normalizedAngularFrequency(frequency, sampleRate: sampleRate)
        let cosW0 = cosf(w0)
        let alpha = sinf(w0) / (2 * max(q, 0.1))
        return normalized(
            b0: (1 + cosW0) / 2,
            b1: -(1 + cosW0),
            b2: (1 + cosW0) / 2,
            a0: 1 + alpha,
            a1: -2 * cosW0,
            a2: 1 - alpha
        )
    }

    static func notch(frequency: Float, sampleRate: Float, q: Float) -> Self {
        let w0 = normalizedAngularFrequency(frequency, sampleRate: sampleRate)
        let cosW0 = cosf(w0)
        let alpha = sinf(w0) / (2 * max(q, 0.1))
        return normalized(
            b0: 1,
            b1: -2 * cosW0,
            b2: 1,
            a0: 1 + alpha,
            a1: -2 * cosW0,
            a2: 1 - alpha
        )
    }

    static func bandPass(frequency: Float, sampleRate: Float, q: Float) -> Self {
        let w0 = normalizedAngularFrequency(frequency, sampleRate: sampleRate)
        let cosW0 = cosf(w0)
        let alpha = sinf(w0) / (2 * max(q, 0.1))
        return normalized(
            b0: alpha,
            b1: 0,
            b2: -alpha,
            a0: 1 + alpha,
            a1: -2 * cosW0,
            a2: 1 - alpha
        )
    }

    static func interpolate(_ a: Self, _ b: Self, t: Float) -> Self {
        Self(
            b0: a.b0 + (b.b0 - a.b0) * t,
            b1: a.b1 + (b.b1 - a.b1) * t,
            b2: a.b2 + (b.b2 - a.b2) * t,
            a1: a.a1 + (b.a1 - a.a1) * t,
            a2: a.a2 + (b.a2 - a.a2) * t
        )
    }

    private static func normalizedAngularFrequency(_ frequency: Float, sampleRate: Float) -> Float {
        let safeFrequency = min(max(frequency, 10), sampleRate * 0.475)
        return 2 * Float.pi * safeFrequency / max(sampleRate, 1)
    }

    private static func normalized(
        b0: Float, b1: Float, b2: Float,
        a0: Float, a1: Float, a2: Float
    ) -> Self {
        let denominator = abs(a0) < 0.000_001 ? 1 : a0
        return Self(
            b0: b0 / denominator,
            b1: b1 / denominator,
            b2: b2 / denominator,
            a1: a1 / denominator,
            a2: a2 / denominator
        )
    }
}

struct BiquadState {
    var z1: Float = 0
    var z2: Float = 0

    mutating func reset() {
        z1 = 0
        z2 = 0
    }

    mutating func softReset(factor: Float = 0.9) {
        z1 *= factor
        z2 *= factor
    }
}

private struct ParametricRuntimeBand {
    var configuration: ParametricEQBand
    var coefficients: BiquadCoefficients = .unity
    var targetCoefficients: BiquadCoefficients = .unity
    var targetCoefficientSampleRate: Float = 0
    var states: [BiquadState] = []
}

private struct DynamicRuntimeBand {
    var configuration: DynamicEQBand
    var detectorCoefficients: BiquadCoefficients = .unity
    var detectorCoefficientSampleRate: Float = 0
    var detectorStates: [BiquadState] = []
    var processingCoefficients: BiquadCoefficients = .unity
    var processingStates: [BiquadState] = []
    var reductionDB: Float = 0
}

private struct MultibandChannelState {
    var low: Float = 0
    var highLowPass: Float = 0
}

private struct MonoEnhanceChannelState {
    var airLowPass: Float = 0
    var loudnessLowPass: Float = 0
    var loudnessHighLowPass: Float = 0
}

private struct MonoEnhanceStereoState {
    var sideLow: Float = 0
    var sideVoiceLow: Float = 0
    var sideVoiceHigh: Float = 0
    var sideStageLow: Float = 0
    var midLow: Float = 0
    var midVoiceLow: Float = 0
    var midVoiceHigh: Float = 0
}

private struct MonoEnhanceCoefficients {
    var airAlpha: Float = 0
    var lowAlpha: Float = 0
    var highAlpha: Float = 0
    var sideLowAlpha: Float = 0
    var voiceLowAlpha: Float = 0
    var voiceHighAlpha: Float = 0
    var stageAlpha: Float = 0
    var transientFastAttack: Float = 0
    var transientFastRelease: Float = 0
    var transientSlowAttack: Float = 0
    var transientSlowRelease: Float = 0
    var microAttack: Float = 0
    var microRelease: Float = 0
    var airAttack: Float = 0
    var airRelease: Float = 0
    var gainAttack: Float = 0
    var gainRelease: Float = 0
}

// MARK: - EQFilter

public final class EQFilter {
    private let lock = NSLock()
    private var isProcessingEnabled = true

    private var graphicMode: GraphicEQMode = .tenBand
    private var userGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var calibrationGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var adaptiveGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var smoothedGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var graphicCoefficients = Array(repeating: BiquadCoefficients.unity, count: GraphicEQMode.tenBand.bandCount)
    private var graphicTargetCoefficients = Array(repeating: BiquadCoefficients.unity, count: GraphicEQMode.tenBand.bandCount)
    private var graphicTargetGains = Array(repeating: Float.nan, count: GraphicEQMode.tenBand.bandCount)
    private var graphicTargetSampleRates = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var graphicStates = Array(repeating: [BiquadState](), count: GraphicEQMode.tenBand.bandCount)

    private var parametricBands: [ParametricRuntimeBand] = []
    private var dynamicBands: [DynamicRuntimeBand] = []
    private var dynamicEQEnabled = false

    private var multiband = MultibandDynamicsConfiguration()
    private var multibandStates: [MultibandChannelState] = []
    private var multibandEnvelopes = Array(repeating: Float(0), count: 3)
    private var multibandFrameValues: [Float] = []
    private var multibandCoefficientSampleRate: Float = 0
    private var multibandLowAlpha: Float = 0
    private var multibandHighAlpha: Float = 0
    private var multibandAttackCoefficient: Float = 0
    private var multibandReleaseCoefficient: Float = 0
    private var multibandThresholdAmplitudes = Array(repeating: Float(0), count: 3)
    private var multibandCurrentGains = Array(repeating: Float(1), count: 3)
    private var multibandGainSteps = Array(repeating: Float(0), count: 3)
    private var multibandControlFramesRemaining = 0

    private var targetMonoEnhance = MonoEnhanceConfiguration.neutral
    private var currentMonoEnhance = MonoEnhanceConfiguration.neutral
    private var monoEnhanceChannelStates: [MonoEnhanceChannelState] = []
    private var monoEnhanceStereoState = MonoEnhanceStereoState()
    private var monoEnhanceFrameValues: [Float] = []
    private var transientFastEnvelope: Float = 0
    private var transientSlowEnvelope: Float = 0
    private var transientGainDB: Float = 0
    private var microDynamicsEnvelope: Float = 0
    private var microDynamicsGainDB: Float = 0
    private var requestedMicroDynamicsDB: Float = 0
    private var monoDynamicsControlFramesRemaining = 0
    private var airEnvelope: Float = 0
    private var monoEnhanceRuntimeNeedsReset = false
    private var monoEnhanceCoefficientSampleRate: Float = 0
    private var monoEnhanceCoefficients = MonoEnhanceCoefficients()

    private var targetPreampDB: Float = 0
    private var currentPreampDB: Float = 0
    private var preampRampStartDB: Float = 0
    private var preampRampProcessedFrames = 0
    private var preampRampTotalFrames = 0
    private var preampRampPending = false
    private var lastSampleRate: Float = 44_100

    public init() {
        // Warm the immutable gain table outside the realtime callback.
        _ = Self.decibelGainLookup.count
        resetGraphicRuntime(count: GraphicEQMode.tenBand.bandCount)
        multibandStates = Array(repeating: MultibandChannelState(), count: 2)
        multibandFrameValues = Array(repeating: 0, count: 6)
        monoEnhanceChannelStates = Array(repeating: MonoEnhanceChannelState(), count: 2)
        monoEnhanceFrameValues = Array(repeating: 0, count: 6)
    }

    public func setProcessingEnabled(_ enabled: Bool) {
        lock.lock()
        isProcessingEnabled = enabled
        lock.unlock()
    }

    public func processingEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isProcessingEnabled
    }

    public func setGraphicMode(_ mode: GraphicEQMode, gains: [Float]? = nil) {
        lock.lock()
        let previousMode = graphicMode
        if mode == previousMode {
            if let gains {
                let sourceMode: GraphicEQMode =
                    gains.count == GraphicEQMode.thirtyTwoBand.bandCount
                        ? .thirtyTwoBand
                        : .tenBand
                userGains = mode.resampledGains(gains, from: sourceMode)
            }
            lock.unlock()
            return
        }
        let previousUserGains = userGains
        let previousCalibrationGains = calibrationGains
        let previousAdaptiveGains = adaptiveGains
        graphicMode = mode
        if let gains {
            let sourceMode: GraphicEQMode = gains.count == GraphicEQMode.thirtyTwoBand.bandCount
                ? .thirtyTwoBand
                : .tenBand
            userGains = mode.resampledGains(gains, from: sourceMode)
        } else {
            userGains = mode.resampledGains(previousUserGains, from: previousMode)
        }
        calibrationGains = mode.resampledGains(previousCalibrationGains, from: previousMode)
            .map { min(max($0, -6), 6) }
        adaptiveGains = mode.resampledGains(previousAdaptiveGains, from: previousMode)
            .map { min(max($0, -1.5), 1.5) }
        resetGraphicRuntime(count: mode.bandCount)
        lock.unlock()
    }

    public func currentGraphicMode() -> GraphicEQMode {
        lock.lock()
        defer { lock.unlock() }
        return graphicMode
    }

    public func currentGraphicGains() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return userGains
    }

    @discardableResult
    public func setGraphicGain(_ gain: Float, at index: Int) -> Float? {
        let clamped = EQBandGain.clamped(gain)
        lock.lock()
        defer { lock.unlock() }
        guard userGains.indices.contains(index) else { return nil }
        if abs(clamped - userGains[index]) > 6 {
            graphicStates[index] = graphicStates[index].map {
                var state = $0
                state.softReset(factor: 0.5)
                return state
            }
        }
        userGains[index] = clamped
        return clamped
    }

    @discardableResult
    public func setGain(_ gain: Float, for band: EQBand) -> Float {
        let clamped = EQBandGain.clamped(gain)
        lock.lock()
        let index = nearestGraphicIndex(to: band.centerFrequency)
        if abs(clamped - userGains[index]) > 6 {
            graphicStates[index] = graphicStates[index].map {
                var state = $0
                state.softReset(factor: 0.5)
                return state
            }
        }
        userGains[index] = clamped
        lock.unlock()
        return clamped
    }

    public func gain(for band: EQBand) -> Float {
        lock.lock()
        defer { lock.unlock() }
        return userGains[nearestGraphicIndex(to: band.centerFrequency)]
    }

    public func setCalibrationGains(_ gains: [Float]) {
        commitNormalizedGains(gains, limit: 6) { filter, normalized in
            filter.calibrationGains = normalized
        }
    }

    public func setAdaptiveGains(_ gains: [Float]) {
        commitNormalizedGains(gains, limit: 1.5) { filter, normalized in
            filter.adaptiveGains = normalized
        }
    }

    public func setPreampDB(_ gainDB: Float) {
        lock.lock()
        let target = min(max(gainDB, -24), 6)
        if abs(target - targetPreampDB) > 0.002 {
            targetPreampDB = target
            preampRampPending = true
        }
        lock.unlock()
    }

    public func setParametricBands(_ bands: [ParametricEQBand]) {
        lock.lock()
        let previous = parametricBands
        lock.unlock()

        var reusedIDs = Set<UUID>()
        let preparedBands = bands.prefix(12).map { configuration in
            let exact = previous.first {
                $0.configuration.id == configuration.id
                    && !reusedIDs.contains($0.configuration.id)
            }
            let nearest = previous
                .filter {
                    !reusedIDs.contains($0.configuration.id)
                        && $0.configuration.type == configuration.type
                }
                .map {
                    (
                        runtime: $0,
                        distance: abs(
                            log2f(
                                max(configuration.frequency, 1)
                                    / max($0.configuration.frequency, 1)
                            )
                        )
                    )
                }
                .filter { $0.distance < 0.18 }
                .min { $0.distance < $1.distance }?
                .runtime
            if var runtime = exact ?? nearest {
                reusedIDs.insert(runtime.configuration.id)
                if runtime.configuration != configuration {
                    runtime.targetCoefficientSampleRate = 0
                }
                runtime.configuration = configuration
                return runtime
            }
            var runtime = ParametricRuntimeBand(configuration: configuration)
            runtime.states = Array(repeating: BiquadState(), count: 2)
            return runtime
        }

        lock.lock()
        parametricBands = preparedBands
        lock.unlock()
    }

    public func setDynamicEQ(enabled: Bool, bands: [DynamicEQBand]) {
        lock.lock()
        let previous = dynamicBands
        lock.unlock()

        var reusedIDs = Set<UUID>()
        let preparedBands = bands.prefix(8).map { configuration in
            let exact = previous.first {
                $0.configuration.id == configuration.id
                    && !reusedIDs.contains($0.configuration.id)
            }
            let nearest = previous
                .filter { !reusedIDs.contains($0.configuration.id) }
                .map {
                    (
                        runtime: $0,
                        distance: abs(
                            log2f(
                                max(configuration.frequency, 1)
                                    / max($0.configuration.frequency, 1)
                            )
                        )
                    )
                }
                .filter { $0.distance < 0.18 }
                .min { $0.distance < $1.distance }?
                .runtime
            if var runtime = exact ?? nearest {
                reusedIDs.insert(runtime.configuration.id)
                if runtime.configuration != configuration {
                    runtime.detectorCoefficientSampleRate = 0
                }
                runtime.configuration = configuration
                return runtime
            }
            var runtime = DynamicRuntimeBand(configuration: configuration)
            runtime.detectorStates = Array(repeating: BiquadState(), count: 2)
            runtime.processingStates = Array(repeating: BiquadState(), count: 2)
            return runtime
        }

        lock.lock()
        dynamicEQEnabled = enabled
        dynamicBands = preparedBands
        lock.unlock()
    }

    public func setMultibandDynamics(_ configuration: MultibandDynamicsConfiguration) {
        lock.lock()
        if multiband != configuration {
            multibandCoefficientSampleRate = 0
            multibandControlFramesRemaining = 0
        }
        multiband = configuration
        lock.unlock()
    }

    public func setMonoEnhance(_ configuration: MonoEnhanceConfiguration) {
        lock.lock()
        targetMonoEnhance = Self.sanitizedMonoEnhance(configuration)
        lock.unlock()
    }

    public func currentMonoEnhanceConfiguration() -> MonoEnhanceConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return targetMonoEnhance
    }

    public func reset() {
        lock.lock()
        userGains = Array(repeating: 0, count: graphicMode.bandCount)
        calibrationGains = Array(repeating: 0, count: graphicMode.bandCount)
        adaptiveGains = Array(repeating: 0, count: graphicMode.bandCount)
        resetGraphicRuntime(count: graphicMode.bandCount)
        targetPreampDB = 0
        currentPreampDB = 0
        preampRampStartDB = 0
        preampRampProcessedFrames = 0
        preampRampTotalFrames = 0
        preampRampPending = false
        targetMonoEnhance = .neutral
        currentMonoEnhance = .neutral
        resetRuntimeStates()
        lock.unlock()
    }

    /// In-place realtime processing. The audio callback never waits for UI
    /// configuration; it skips one block if a setting is being committed.
    public func process(_ buffer: AudioBuffer) -> AudioBuffer {
        // 有界重试：EQ/预放大被整块跳过时会产生瞬间的响度阶跃（“坎”），
        // 比在实时线程上多等几十微秒糟糕得多。
        guard acquireRealtimeAudioLock(lock) else { return buffer }
        defer { lock.unlock() }
        guard isProcessingEnabled else { return buffer }

        let sampleRate = Float(buffer.sampleRate)
        let channelCount = buffer.channelCount
        let frameCount = buffer.frameCount
        let data = buffer.data
        guard sampleRate > 0, channelCount > 0, frameCount > 0 else { return buffer }

        if abs(sampleRate - lastSampleRate) > 1 {
            lastSampleRate = sampleRate
            resetRuntimeStates()
        }

        processGraphicEQ(data, frames: frameCount, channels: channelCount, sampleRate: sampleRate)
        processParametricEQ(data, frames: frameCount, channels: channelCount, sampleRate: sampleRate)
        processDynamicEQ(data, frames: frameCount, channels: channelCount, sampleRate: sampleRate)
        processMultibandDynamics(data, frames: frameCount, channels: channelCount, sampleRate: sampleRate)
        processMonoEnhance(data, frames: frameCount, channels: channelCount, sampleRate: sampleRate)
        applyPreamp(
            data,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
        return buffer
    }

    private func processGraphicEQ(
        _ data: UnsafeMutablePointer<Float>, frames: Int, channels: Int, sampleRate: Float
    ) {
        let frequencies = graphicMode.centerFrequencies
        let qValues = graphicMode.qValues
        for index in frequencies.indices {
            let frequency = frequencies[index]
            let target = min(max(userGains[index] + calibrationGains[index] + adaptiveGains[index], -18), 18)
            let current = smoothedGains[index]
            smoothedGains[index] = abs(target - current) < 0.005
                ? target
                : current + (target - current) * 0.08

            let gain = smoothedGains[index]
            if !graphicTargetGains[index].isFinite
                || abs(graphicTargetGains[index] - gain) > 0.000_1
                || abs(graphicTargetSampleRates[index] - sampleRate) > 1 {
                if abs(gain) < 0.005 {
                    graphicTargetCoefficients[index] = .unity
                } else if graphicMode == .tenBand, index == frequencies.startIndex {
                    graphicTargetCoefficients[index] = .lowShelf(
                        gainDB: gain,
                        frequency: frequency,
                        sampleRate: sampleRate
                    )
                } else if graphicMode == .tenBand,
                          index == frequencies.index(before: frequencies.endIndex) {
                    graphicTargetCoefficients[index] = .highShelf(
                        gainDB: gain,
                        frequency: frequency,
                        sampleRate: sampleRate
                    )
                } else {
                    graphicTargetCoefficients[index] = .peakingEQ(
                        gainDB: gain,
                        centerFrequency: frequency,
                        sampleRate: sampleRate,
                        q: qValues[index]
                    )
                }
                graphicTargetGains[index] = gain
                graphicTargetSampleRates[index] = sampleRate
            }
            graphicCoefficients[index] = .interpolate(
                graphicCoefficients[index],
                graphicTargetCoefficients[index],
                t: 0.35
            )
            if abs(target) < 0.005,
               abs(gain) < 0.005,
               Self.isNearUnity(graphicCoefficients[index]) {
                graphicCoefficients[index] = .unity
                graphicStates[index].removeAll(keepingCapacity: true)
                continue
            }
            ensureStateCount(&graphicStates[index], channels: channels)
            processBiquad(
                data,
                frames: frames,
                channels: channels,
                coefficients: graphicCoefficients[index],
                states: &graphicStates[index]
            )
        }
    }

    private func processParametricEQ(
        _ data: UnsafeMutablePointer<Float>, frames: Int, channels: Int, sampleRate: Float
    ) {
        for index in parametricBands.indices where parametricBands[index].configuration.isEnabled {
            let configuration = parametricBands[index].configuration
            if abs(parametricBands[index].targetCoefficientSampleRate - sampleRate) > 1 {
                parametricBands[index].targetCoefficients = coefficients(
                    for: configuration,
                    sampleRate: sampleRate
                )
                parametricBands[index].targetCoefficientSampleRate = sampleRate
            }
            parametricBands[index].coefficients = .interpolate(
                parametricBands[index].coefficients,
                parametricBands[index].targetCoefficients,
                t: 0.28
            )
            if configuration.type.usesGain,
               abs(configuration.gainDB) < 0.005,
               Self.isNearUnity(parametricBands[index].coefficients) {
                parametricBands[index].coefficients = .unity
                parametricBands[index].states.removeAll(keepingCapacity: true)
                continue
            }
            ensureStateCount(&parametricBands[index].states, channels: channels)
            processBiquad(
                data,
                frames: frames,
                channels: channels,
                coefficients: parametricBands[index].coefficients,
                states: &parametricBands[index].states
            )
        }
    }

    private func processDynamicEQ(
        _ data: UnsafeMutablePointer<Float>, frames: Int, channels: Int, sampleRate: Float
    ) {
        guard dynamicEQEnabled else { return }
        let sampleCount = max(frames * channels, 1)

        for index in dynamicBands.indices where dynamicBands[index].configuration.isEnabled {
            let configuration = dynamicBands[index].configuration
            if abs(dynamicBands[index].detectorCoefficientSampleRate - sampleRate) > 1 {
                dynamicBands[index].detectorCoefficients = .bandPass(
                    frequency: configuration.frequency,
                    sampleRate: sampleRate,
                    q: configuration.q
                )
                dynamicBands[index].detectorCoefficientSampleRate = sampleRate
            }
            ensureStateCount(&dynamicBands[index].detectorStates, channels: channels)

            var energy: Float = 0
            for channel in 0..<channels {
                var z1 = dynamicBands[index].detectorStates[channel].z1
                var z2 = dynamicBands[index].detectorStates[channel].z2
                let c = dynamicBands[index].detectorCoefficients
                for frame in 0..<frames {
                    let sample = data[frame * channels + channel]
                    let output = c.b0 * sample + z1
                    z1 = c.b1 * sample - c.a1 * output + z2
                    z2 = c.b2 * sample - c.a2 * output
                    energy += output * output
                }
                dynamicBands[index].detectorStates[channel] = BiquadState(z1: z1, z2: z2)
            }

            let levelDB = 20 * log10f(max(sqrtf(energy / Float(sampleCount)), 0.000_001))
            let excess = max(0, levelDB - configuration.thresholdDB)
            let requestedReduction = min(
                configuration.maxReductionDB,
                excess * (1 - 1 / max(configuration.ratio, 1))
            )
            let timeMS = requestedReduction > dynamicBands[index].reductionDB
                ? configuration.attackMS
                : configuration.releaseMS
            let duration = Float(frames) / sampleRate
            let smoothing = 1 - expf(-duration / max(timeMS / 1_000, 0.001))
            dynamicBands[index].reductionDB += (requestedReduction - dynamicBands[index].reductionDB) * smoothing

            let target = BiquadCoefficients.peakingEQ(
                gainDB: -dynamicBands[index].reductionDB,
                centerFrequency: configuration.frequency,
                sampleRate: sampleRate,
                q: configuration.q
            )
            dynamicBands[index].processingCoefficients = .interpolate(
                dynamicBands[index].processingCoefficients,
                target,
                t: 0.4
            )
            ensureStateCount(&dynamicBands[index].processingStates, channels: channels)
            processBiquad(
                data,
                frames: frames,
                channels: channels,
                coefficients: dynamicBands[index].processingCoefficients,
                states: &dynamicBands[index].processingStates
            )
        }
    }

    private func processMultibandDynamics(
        _ data: UnsafeMutablePointer<Float>, frames: Int, channels: Int, sampleRate: Float
    ) {
        guard multiband.isEnabled else { return }
        if multibandStates.count != channels {
            multibandStates = Array(repeating: MultibandChannelState(), count: channels)
            multibandFrameValues = Array(repeating: 0, count: channels * 3)
        }

        prepareMultibandCoefficientsIfNeeded(sampleRate: sampleRate)

        for frame in 0..<frames {
            var peakLow: Float = 0
            var peakMid: Float = 0
            var peakHigh: Float = 0
            for channel in 0..<channels {
                let index = frame * channels + channel
                let input = data[index]
                multibandStates[channel].low += multibandLowAlpha * (
                    input - multibandStates[channel].low
                )
                multibandStates[channel].highLowPass += multibandHighAlpha * (
                    input - multibandStates[channel].highLowPass
                )
                let low = multibandStates[channel].low
                let high = input - multibandStates[channel].highLowPass
                let mid = input - low - high
                multibandFrameValues[channel * 3] = low
                multibandFrameValues[channel * 3 + 1] = mid
                multibandFrameValues[channel * 3 + 2] = high
                peakLow = max(peakLow, abs(low))
                peakMid = max(peakMid, abs(mid))
                peakHigh = max(peakHigh, abs(high))
            }

            for band in 0..<3 {
                let detector: Float
                switch band {
                case 0: detector = peakLow
                case 1: detector = peakMid
                default: detector = peakHigh
                }
                let coefficient = detector > multibandEnvelopes[band]
                    ? multibandAttackCoefficient
                    : multibandReleaseCoefficient
                multibandEnvelopes[band] = coefficient * multibandEnvelopes[band] + (1 - coefficient) * detector
            }

            if multibandControlFramesRemaining <= 0 {
                for band in 0..<3 {
                    let targetGain: Float
                    if multiband.maxReductionDB[band] <= 0
                        || multibandEnvelopes[band] <= multibandThresholdAmplitudes[band] {
                        targetGain = 1
                    } else {
                        let levelDB = 20 * log10f(
                            max(multibandEnvelopes[band], 0.000_001)
                        )
                        let excess = max(0, levelDB - multiband.thresholdsDB[band])
                        let reduction = min(
                            multiband.maxReductionDB[band],
                            excess * (1 - 1 / multiband.ratios[band])
                        )
                        targetGain = Self.linearGain(decibels: -reduction)
                    }
                    multibandGainSteps[band] = (
                        targetGain - multibandCurrentGains[band]
                    ) / Float(Self.dynamicsControlInterval)
                }
                multibandControlFramesRemaining = Self.dynamicsControlInterval
            }

            for band in 0..<3 {
                multibandCurrentGains[band] += multibandGainSteps[band]
            }
            multibandControlFramesRemaining -= 1

            for channel in 0..<channels {
                let values = channel * 3
                data[frame * channels + channel] =
                    multibandFrameValues[values] * multibandCurrentGains[0]
                    + multibandFrameValues[values + 1] * multibandCurrentGains[1]
                    + multibandFrameValues[values + 2] * multibandCurrentGains[2]
            }
        }
    }

    /// Mono Enhance stays in the native Float32 path. It uses only linked
    /// envelopes, one-pole band separation and Mid/Side recombination, so it
    /// adds no FFT window latency and never rebuilds the FFmpeg filter graph.
    private func processMonoEnhance(
        _ data: UnsafeMutablePointer<Float>, frames: Int, channels: Int, sampleRate: Float
    ) {
        smoothMonoEnhanceTarget(frames: frames, sampleRate: sampleRate)
        guard currentMonoEnhance.hasAudibleProcessing else {
            if !targetMonoEnhance.hasAudibleProcessing {
                resetMonoEnhanceRuntimeIfSilent()
            }
            return
        }
        monoEnhanceRuntimeNeedsReset = true

        if monoEnhanceChannelStates.count != channels {
            monoEnhanceChannelStates = Array(
                repeating: MonoEnhanceChannelState(),
                count: channels
            )
            monoEnhanceFrameValues = Array(repeating: 0, count: channels * 3)
            monoEnhanceStereoState = MonoEnhanceStereoState()
        } else if monoEnhanceFrameValues.count != channels * 3 {
            monoEnhanceFrameValues = Array(repeating: 0, count: channels * 3)
        }

        prepareMonoEnhanceCoefficientsIfNeeded(sampleRate: sampleRate)
        let c = monoEnhanceCoefficients

        for frame in 0..<frames {
            var linkedPeak: Float = 0
            var highPeak: Float = 0

            for channel in 0..<channels {
                let dataIndex = frame * channels + channel
                let stateIndex = channel
                let raw = data[dataIndex]
                linkedPeak = max(linkedPeak, abs(raw))

                monoEnhanceChannelStates[stateIndex].loudnessLowPass += c.lowAlpha * (
                    raw - monoEnhanceChannelStates[stateIndex].loudnessLowPass
                )
                monoEnhanceChannelStates[stateIndex].loudnessHighLowPass += c.highAlpha * (
                    raw - monoEnhanceChannelStates[stateIndex].loudnessHighLowPass
                )
                monoEnhanceChannelStates[stateIndex].airLowPass += c.airAlpha * (
                    raw - monoEnhanceChannelStates[stateIndex].airLowPass
                )

                let low = monoEnhanceChannelStates[stateIndex].loudnessLowPass
                let high = raw - monoEnhanceChannelStates[stateIndex].loudnessHighLowPass
                let air = raw - monoEnhanceChannelStates[stateIndex].airLowPass
                let values = channel * 3
                monoEnhanceFrameValues[values] = raw
                monoEnhanceFrameValues[values + 1] = low
                monoEnhanceFrameValues[values + 2] = high + air * 0.5
                highPeak = max(highPeak, abs(air))
            }

            updateEnvelope(
                &transientFastEnvelope,
                input: linkedPeak,
                attack: c.transientFastAttack,
                release: c.transientFastRelease
            )
            updateEnvelope(
                &transientSlowEnvelope,
                input: linkedPeak,
                attack: c.transientSlowAttack,
                release: c.transientSlowRelease
            )
            updateEnvelope(
                &microDynamicsEnvelope,
                input: linkedPeak,
                attack: c.microAttack,
                release: c.microRelease
            )
            updateEnvelope(
                &airEnvelope,
                input: highPeak,
                attack: c.airAttack,
                release: c.airRelease
            )

            let transientDelta = max(0, transientFastEnvelope - transientSlowEnvelope)
                / max(transientSlowEnvelope, 0.02)
            let sustainDensity = max(0, transientSlowEnvelope - transientFastEnvelope * 0.72)
                / max(transientSlowEnvelope, 0.02)
            let requestedTransientDB = min(
                1.8,
                currentMonoEnhance.transientAttack * min(transientDelta, 1.5) * 1.55
                    + currentMonoEnhance.transientSustain * min(sustainDensity, 1) * 0.72
            )
            smoothGain(
                &transientGainDB,
                target: requestedTransientDB,
                attack: c.gainAttack,
                release: c.gainRelease
            )

            if monoDynamicsControlFramesRemaining <= 0 {
                let microLevelDB = 20 * log10f(
                    max(microDynamicsEnvelope, 0.000_01)
                )
                if microLevelDB < -24, microLevelDB > -54 {
                    requestedMicroDynamicsDB = min(
                        0.8,
                        (-24 - microLevelDB) * 0.035
                    ) * currentMonoEnhance.microDynamics
                } else if microLevelDB > -8 {
                    requestedMicroDynamicsDB = -min(
                        0.38,
                        (microLevelDB + 8) * 0.035
                    ) * currentMonoEnhance.microDynamics
                } else {
                    requestedMicroDynamicsDB = 0
                }
                monoDynamicsControlFramesRemaining = Self.dynamicsControlInterval
            }
            monoDynamicsControlFramesRemaining -= 1
            smoothGain(
                &microDynamicsGainDB,
                target: requestedMicroDynamicsDB,
                attack: c.gainAttack,
                release: c.gainRelease
            )

            let combinedDynamicsDB = transientGainDB + microDynamicsGainDB
            let dynamicsGain = abs(combinedDynamicsDB) < 0.000_1
                ? 1
                : Self.linearGain(decibels: combinedDynamicsDB)
            let sibilance = min(1, max(0, (airEnvelope - 0.045) / 0.16))
            let airMix = currentMonoEnhance.airAmount * 0.22
                - currentMonoEnhance.deEssAmount * sibilance * 0.12
            let lowLevelAmount = currentMonoEnhance.lowLevelCompensation

            for channel in 0..<channels {
                let values = channel * 3
                let base = monoEnhanceFrameValues[values]
                let low = monoEnhanceFrameValues[values + 1]
                let high = monoEnhanceFrameValues[values + 2]
                data[frame * channels + channel] = base * dynamicsGain
                    + low * lowLevelAmount * 0.11
                    + high * (lowLevelAmount * 0.04 + airMix)
            }

            guard channels >= 2 else { continue }
            let leftIndex = frame * channels
            let rightIndex = leftIndex + 1
            let left = data[leftIndex]
            let right = data[rightIndex]
            var mid = (left + right) * 0.5
            var side = (left - right) * 0.5

            monoEnhanceStereoState.sideLow += c.sideLowAlpha * (
                side - monoEnhanceStereoState.sideLow
            )
            monoEnhanceStereoState.sideVoiceLow += c.voiceLowAlpha * (
                side - monoEnhanceStereoState.sideVoiceLow
            )
            monoEnhanceStereoState.sideVoiceHigh += c.voiceHighAlpha * (
                side - monoEnhanceStereoState.sideVoiceHigh
            )
            monoEnhanceStereoState.sideStageLow += c.stageAlpha * (
                side - monoEnhanceStereoState.sideStageLow
            )
            monoEnhanceStereoState.midLow += c.sideLowAlpha * (
                mid - monoEnhanceStereoState.midLow
            )
            monoEnhanceStereoState.midVoiceLow += c.voiceLowAlpha * (
                mid - monoEnhanceStereoState.midVoiceLow
            )
            monoEnhanceStereoState.midVoiceHigh += c.voiceHighAlpha * (
                mid - monoEnhanceStereoState.midVoiceHigh
            )

            let sideVoice = monoEnhanceStereoState.sideVoiceHigh
                - monoEnhanceStereoState.sideVoiceLow
            let midVoice = monoEnhanceStereoState.midVoiceHigh
                - monoEnhanceStereoState.midVoiceLow
            let stageHigh = side - monoEnhanceStereoState.sideStageLow
            side -= monoEnhanceStereoState.sideLow
                * currentMonoEnhance.lowFrequencyFocus * 0.72
            side -= sideVoice * currentMonoEnhance.vocalFocus * 0.14
            side += stageHigh * currentMonoEnhance.stageWidth * 0.85
            mid += monoEnhanceStereoState.midLow
                * currentMonoEnhance.lowFrequencyFocus * 0.06
            mid += midVoice * currentMonoEnhance.vocalFocus * 0.06

            data[leftIndex] = mid + side
            data[rightIndex] = mid - side
        }
    }

    private func applyPreamp(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int,
        sampleRate: Float
    ) {
        if preampRampPending {
            preampRampStartDB = currentPreampDB
            preampRampProcessedFrames = 0
            preampRampTotalFrames = max(1, Int(sampleRate * 0.32))
            preampRampPending = false
        }

        let isRamping = preampRampProcessedFrames < preampRampTotalFrames
        if !isRamping {
            currentPreampDB = targetPreampDB
            guard abs(currentPreampDB) > 0.000_1 else { return }
            let gain = Self.linearGain(decibels: currentPreampDB)
            for index in 0..<(frameCount * channelCount) {
                data[index] *= gain
            }
            return
        }

        for frame in 0..<frameCount {
            let progressed = min(
                preampRampTotalFrames,
                preampRampProcessedFrames + frame + 1
            )
            let progress = Float(progressed) / Float(preampRampTotalFrames)
            let eased = progress * progress * (3 - 2 * progress)
            let gainDB = preampRampStartDB
                + (targetPreampDB - preampRampStartDB) * eased
            let gain = Self.linearGain(decibels: gainDB)
            let baseIndex = frame * channelCount
            for channel in 0..<channelCount {
                data[baseIndex + channel] *= gain
            }
        }
        preampRampProcessedFrames = min(
            preampRampTotalFrames,
            preampRampProcessedFrames + frameCount
        )
        let progress = Float(preampRampProcessedFrames)
            / Float(preampRampTotalFrames)
        let eased = progress * progress * (3 - 2 * progress)
        currentPreampDB = preampRampStartDB
            + (targetPreampDB - preampRampStartDB) * eased
    }

    private func processBiquad(
        _ data: UnsafeMutablePointer<Float>,
        frames: Int,
        channels: Int,
        coefficients c: BiquadCoefficients,
        states: inout [BiquadState]
    ) {
        for channel in 0..<channels {
            var z1 = states[channel].z1
            var z2 = states[channel].z2
            for frame in 0..<frames {
                let index = frame * channels + channel
                let input = data[index]
                let output = c.b0 * input + z1
                z1 = c.b1 * input - c.a1 * output + z2
                z2 = c.b2 * input - c.a2 * output
                data[index] = output
            }
            states[channel] = BiquadState(z1: z1, z2: z2)
        }
    }

    private func coefficients(for band: ParametricEQBand, sampleRate: Float) -> BiquadCoefficients {
        switch band.type {
        case .peak:
            return .peakingEQ(gainDB: band.gainDB, centerFrequency: band.frequency, sampleRate: sampleRate, q: band.q)
        case .lowShelf:
            return .lowShelf(gainDB: band.gainDB, frequency: band.frequency, sampleRate: sampleRate)
        case .highShelf:
            return .highShelf(gainDB: band.gainDB, frequency: band.frequency, sampleRate: sampleRate)
        case .lowPass:
            return .lowPass(frequency: band.frequency, sampleRate: sampleRate, q: band.q)
        case .highPass:
            return .highPass(frequency: band.frequency, sampleRate: sampleRate, q: band.q)
        case .notch:
            return .notch(frequency: band.frequency, sampleRate: sampleRate, q: band.q)
        }
    }

    private func ensureStateCount(_ states: inout [BiquadState], channels: Int) {
        if states.count != channels {
            states = Array(repeating: BiquadState(), count: channels)
        }
    }

    private func prepareMultibandCoefficientsIfNeeded(sampleRate: Float) {
        guard abs(multibandCoefficientSampleRate - sampleRate) > 1 else { return }
        multibandCoefficientSampleRate = sampleRate
        multibandLowAlpha = 1 - expf(
            -2 * Float.pi * multiband.lowCrossoverHz / sampleRate
        )
        multibandHighAlpha = 1 - expf(
            -2 * Float.pi * multiband.highCrossoverHz / sampleRate
        )
        multibandAttackCoefficient = expf(
            -1 / (max(multiband.attackMS, 1) * 0.001 * sampleRate)
        )
        multibandReleaseCoefficient = expf(
            -1 / (max(multiband.releaseMS, 1) * 0.001 * sampleRate)
        )
        for band in 0..<3 {
            multibandThresholdAmplitudes[band] = Self.linearGain(
                decibels: multiband.thresholdsDB[band]
            )
        }
    }

    private func prepareMonoEnhanceCoefficientsIfNeeded(sampleRate: Float) {
        guard abs(monoEnhanceCoefficientSampleRate - sampleRate) > 1 else { return }
        monoEnhanceCoefficientSampleRate = sampleRate
        monoEnhanceCoefficients = MonoEnhanceCoefficients(
            airAlpha: onePoleAlpha(frequency: 6_800, sampleRate: sampleRate),
            lowAlpha: onePoleAlpha(frequency: 135, sampleRate: sampleRate),
            highAlpha: onePoleAlpha(frequency: 3_600, sampleRate: sampleRate),
            sideLowAlpha: onePoleAlpha(frequency: 115, sampleRate: sampleRate),
            voiceLowAlpha: onePoleAlpha(frequency: 180, sampleRate: sampleRate),
            voiceHighAlpha: onePoleAlpha(frequency: 4_600, sampleRate: sampleRate),
            stageAlpha: onePoleAlpha(frequency: 2_100, sampleRate: sampleRate),
            transientFastAttack: envelopeCoefficient(
                milliseconds: 1.8,
                sampleRate: sampleRate
            ),
            transientFastRelease: envelopeCoefficient(
                milliseconds: 42,
                sampleRate: sampleRate
            ),
            transientSlowAttack: envelopeCoefficient(
                milliseconds: 24,
                sampleRate: sampleRate
            ),
            transientSlowRelease: envelopeCoefficient(
                milliseconds: 190,
                sampleRate: sampleRate
            ),
            microAttack: envelopeCoefficient(milliseconds: 12, sampleRate: sampleRate),
            microRelease: envelopeCoefficient(milliseconds: 170, sampleRate: sampleRate),
            airAttack: envelopeCoefficient(milliseconds: 2.5, sampleRate: sampleRate),
            airRelease: envelopeCoefficient(milliseconds: 85, sampleRate: sampleRate),
            gainAttack: envelopeCoefficient(milliseconds: 4, sampleRate: sampleRate),
            gainRelease: envelopeCoefficient(milliseconds: 75, sampleRate: sampleRate)
        )
    }

    private func smoothMonoEnhanceTarget(frames: Int, sampleRate: Float) {
        let duration = Float(frames) / max(sampleRate, 1)
        let amount = 1 - expf(-duration / 0.32)
        @inline(__always)
        func moved(_ current: Float, _ target: Float) -> Float {
            let next = current + (target - current) * amount
            return abs(next - target) < 0.000_2 ? target : next
        }

        let target = targetMonoEnhance.hasAudibleProcessing
            ? targetMonoEnhance
            : .neutral
        let next = MonoEnhanceConfiguration(
            isEnabled: true,
            transientAttack: moved(currentMonoEnhance.transientAttack, target.transientAttack),
            transientSustain: moved(currentMonoEnhance.transientSustain, target.transientSustain),
            vocalFocus: moved(currentMonoEnhance.vocalFocus, target.vocalFocus),
            airAmount: moved(currentMonoEnhance.airAmount, target.airAmount),
            deEssAmount: moved(currentMonoEnhance.deEssAmount, target.deEssAmount),
            lowFrequencyFocus: moved(currentMonoEnhance.lowFrequencyFocus, target.lowFrequencyFocus),
            stageWidth: moved(currentMonoEnhance.stageWidth, target.stageWidth),
            microDynamics: moved(currentMonoEnhance.microDynamics, target.microDynamics),
            lowLevelCompensation: moved(
                currentMonoEnhance.lowLevelCompensation,
                target.lowLevelCompensation
            )
        )
        currentMonoEnhance = next.hasAudibleProcessing ? next : .neutral
    }

    private func resetMonoEnhanceRuntimeIfSilent() {
        guard monoEnhanceRuntimeNeedsReset else { return }
        for index in monoEnhanceChannelStates.indices {
            monoEnhanceChannelStates[index] = MonoEnhanceChannelState()
        }
        for index in monoEnhanceFrameValues.indices {
            monoEnhanceFrameValues[index] = 0
        }
        monoEnhanceStereoState = MonoEnhanceStereoState()
        transientFastEnvelope = 0
        transientSlowEnvelope = 0
        transientGainDB = 0
        microDynamicsEnvelope = 0
        microDynamicsGainDB = 0
        requestedMicroDynamicsDB = 0
        monoDynamicsControlFramesRemaining = 0
        airEnvelope = 0
        monoEnhanceRuntimeNeedsReset = false
    }

    @inline(__always)
    private func onePoleAlpha(frequency: Float, sampleRate: Float) -> Float {
        1 - expf(-2 * Float.pi * min(frequency, sampleRate * 0.45) / max(sampleRate, 1))
    }

    @inline(__always)
    private func envelopeCoefficient(milliseconds: Float, sampleRate: Float) -> Float {
        expf(-1 / (max(milliseconds, 0.1) * 0.001 * max(sampleRate, 1)))
    }

    @inline(__always)
    private func updateEnvelope(
        _ envelope: inout Float,
        input: Float,
        attack: Float,
        release: Float
    ) {
        let coefficient = input > envelope ? attack : release
        envelope = coefficient * envelope + (1 - coefficient) * input
    }

    @inline(__always)
    private func smoothGain(
        _ gain: inout Float,
        target: Float,
        attack: Float,
        release: Float
    ) {
        let coefficient = target > gain ? attack : release
        gain = coefficient * gain + (1 - coefficient) * target
    }

    private static func sanitizedMonoEnhance(
        _ configuration: MonoEnhanceConfiguration
    ) -> MonoEnhanceConfiguration {
        guard configuration.isEnabled else { return .neutral }
        return MonoEnhanceConfiguration(
            isEnabled: true,
            transientAttack: configuration.transientAttack,
            transientSustain: configuration.transientSustain,
            vocalFocus: configuration.vocalFocus,
            airAmount: configuration.airAmount,
            deEssAmount: configuration.deEssAmount,
            lowFrequencyFocus: configuration.lowFrequencyFocus,
            stageWidth: configuration.stageWidth,
            microDynamics: configuration.microDynamics,
            lowLevelCompensation: configuration.lowLevelCompensation
        )
    }

    /// Dynamics envelopes still update per sample. Only the expensive
    /// log/gain conversion runs at this sub-millisecond control interval, and
    /// output gain is linearly interpolated between control points.
    private static let dynamicsControlInterval = 8
    private static let decibelGainMinimum: Float = -80
    private static let decibelGainMaximum: Float = 24
    private static let decibelGainStepsPerDB: Float = 512
    private static let decibelGainLookup: [Float] = {
        let count = Int(
            (decibelGainMaximum - decibelGainMinimum) * decibelGainStepsPerDB
        ) + 1
        return (0..<count).map { index in
            let decibels = decibelGainMinimum
                + Float(index) / decibelGainStepsPerDB
            return powf(10, decibels / 20)
        }
    }()

    /// Bounded linear interpolation differs by far less than 0.001 dB while
    /// avoiding a transcendental `powf` call for every audio frame.
    @inline(__always)
    private static func linearGain(decibels: Float) -> Float {
        let bounded = min(max(decibels, decibelGainMinimum), decibelGainMaximum)
        let position = (bounded - decibelGainMinimum) * decibelGainStepsPerDB
        let lowerIndex = min(Int(position), decibelGainLookup.count - 1)
        let upperIndex = min(lowerIndex + 1, decibelGainLookup.count - 1)
        let fraction = position - Float(lowerIndex)
        let lower = decibelGainLookup[lowerIndex]
        return lower + (decibelGainLookup[upperIndex] - lower) * fraction
    }

    private func resetRuntimeStates() {
        resetGraphicRuntime(count: graphicMode.bandCount)
        for index in parametricBands.indices {
            parametricBands[index].states = Array(repeating: BiquadState(), count: 2)
            parametricBands[index].coefficients = .unity
            parametricBands[index].targetCoefficients = .unity
            parametricBands[index].targetCoefficientSampleRate = 0
        }
        for index in dynamicBands.indices {
            dynamicBands[index].detectorStates = Array(repeating: BiquadState(), count: 2)
            dynamicBands[index].processingStates = Array(repeating: BiquadState(), count: 2)
            dynamicBands[index].detectorCoefficients = .unity
            dynamicBands[index].detectorCoefficientSampleRate = 0
            dynamicBands[index].processingCoefficients = .unity
            dynamicBands[index].reductionDB = 0
        }
        multibandStates = Array(repeating: MultibandChannelState(), count: 2)
        multibandFrameValues = Array(repeating: 0, count: 6)
        multibandEnvelopes = Array(repeating: 0, count: 3)
        multibandCurrentGains = Array(repeating: 1, count: 3)
        multibandGainSteps = Array(repeating: 0, count: 3)
        multibandControlFramesRemaining = 0
        multibandCoefficientSampleRate = 0
        monoEnhanceChannelStates = Array(repeating: MonoEnhanceChannelState(), count: 2)
        monoEnhanceFrameValues = Array(repeating: 0, count: 6)
        monoEnhanceStereoState = MonoEnhanceStereoState()
        transientFastEnvelope = 0
        transientSlowEnvelope = 0
        transientGainDB = 0
        microDynamicsEnvelope = 0
        microDynamicsGainDB = 0
        requestedMicroDynamicsDB = 0
        monoDynamicsControlFramesRemaining = 0
        airEnvelope = 0
        monoEnhanceRuntimeNeedsReset = false
        monoEnhanceCoefficientSampleRate = 0
    }

    private func resetGraphicRuntime(count: Int) {
        smoothedGains = Array(repeating: 0, count: count)
        graphicCoefficients = Array(repeating: .unity, count: count)
        graphicTargetCoefficients = Array(repeating: .unity, count: count)
        graphicTargetGains = Array(repeating: .nan, count: count)
        graphicTargetSampleRates = Array(repeating: 0, count: count)
        graphicStates = (0..<count).map { _ in
            Array(repeating: BiquadState(), count: 2)
        }
    }

    private func nearestGraphicIndex(to frequency: Float) -> Int {
        let frequencies = graphicMode.centerFrequencies
        return frequencies.indices.min {
            abs(logf(frequencies[$0]) - logf(frequency)) < abs(logf(frequencies[$1]) - logf(frequency))
        } ?? 0
    }

    /// Resampling allocates and may perform interpolation. Keep that work out of
    /// the lock held by the realtime EQ callback; the critical section becomes
    /// a mode check plus one Array reference assignment.
    private func commitNormalizedGains(
        _ gains: [Float],
        limit: Float,
        assign: (EQFilter, [Float]) -> Void
    ) {
        while true {
            lock.lock()
            let mode = graphicMode
            lock.unlock()

            let normalized = normalizedGains(gains, for: mode, limit: limit)

            lock.lock()
            guard graphicMode == mode else {
                lock.unlock()
                continue
            }
            assign(self, normalized)
            lock.unlock()
            return
        }
    }

    private func normalizedGains(
        _ gains: [Float],
        for mode: GraphicEQMode,
        limit: Float
    ) -> [Float] {
        let sourceMode: GraphicEQMode = gains.count == GraphicEQMode.thirtyTwoBand.bandCount
            ? .thirtyTwoBand
            : .tenBand
        return mode.resampledGains(gains, from: sourceMode)
            .map { min(max($0, -limit), limit) }
    }

    private static func isNearUnity(_ coefficients: BiquadCoefficients) -> Bool {
        abs(coefficients.b0 - 1) < 0.000_1
            && abs(coefficients.b1) < 0.000_1
            && abs(coefficients.b2) < 0.000_1
            && abs(coefficients.a1) < 0.000_1
            && abs(coefficients.a2) < 0.000_1
    }
}

private extension ParametricEQFilterType {
    var usesGain: Bool {
        switch self {
        case .peak, .lowShelf, .highShelf: return true
        case .lowPass, .highPass, .notch: return false
        }
    }
}
