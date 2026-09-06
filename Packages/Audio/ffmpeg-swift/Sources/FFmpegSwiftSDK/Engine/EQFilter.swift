// EQFilter.swift
// FFmpegSwiftSDK
//
// Mono realtime equalizer and calibration stage. The processor owns the
// graphic, parametric and dynamics filters so interactive changes never need
// to rebuild the FFmpeg filter graph.

import Foundation

// MARK: - Biquad

struct BiquadCoefficients: Equatable {
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
    // Input/output history remains meaningful when coefficients change.
    // Transposed delay values embed the old coefficients and inject an impulse
    // if reused unchanged with the next control update.
    private var x1: Double = 0
    private var x2: Double = 0
    private var y1: Double = 0
    private var y2: Double = 0

    mutating func reset() {
        self = BiquadState()
    }

    @inline(__always)
    mutating func process(_ input: Float, coefficients c: BiquadCoefficients) -> Float {
        let x = Double(input)
        let y = Double(c.b0) * x + Double(c.b1) * x1 + Double(c.b2) * x2
            - Double(c.a1) * y1 - Double(c.a2) * y2
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        return Float(y)
    }
}

private final class ParametricRuntimeBand {
    var configuration: ParametricEQBand
    var coefficients: BiquadCoefficients = .unity
    var targetCoefficients: BiquadCoefficients = .unity
    var targetCoefficientSampleRate: Float = 0
    var states = Array(repeating: BiquadState(), count: 2)

    init(configuration: ParametricEQBand) { self.configuration = configuration }

    func reset() {
        coefficients = .unity
        targetCoefficients = .unity
        targetCoefficientSampleRate = 0
        for index in states.indices { states[index].reset() }
    }
}

private final class DynamicRuntimeBand {
    var configuration: DynamicEQBand
    var detectorCoefficients: BiquadCoefficients = .unity
    var detectorCoefficientSampleRate: Float = 0
    var detectorStates = Array(repeating: BiquadState(), count: 2)
    var processingCoefficients: BiquadCoefficients = .unity
    var processingStates = Array(repeating: BiquadState(), count: 2)
    var reductionDB: Float = 0

    init(configuration: DynamicEQBand) { self.configuration = configuration }

    func reset() {
        detectorCoefficients = .unity
        detectorCoefficientSampleRate = 0
        processingCoefficients = .unity
        reductionDB = 0
        for index in detectorStates.indices { detectorStates[index].reset() }
        for index in processingStates.indices { processingStates[index].reset() }
    }
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
    private struct Configuration: Equatable {
        var enabled = true
        var mode = GraphicEQMode.tenBand
        var gains = Array(repeating: Float(0), count: 10)
        var calibration = Array(repeating: Float(0), count: 10)
        var adaptive = Array(repeating: Float(0), count: 10)
        var hearingLeft = Array(repeating: Float(0), count: 10)
        var hearingRight = Array(repeating: Float(0), count: 10)
        var preampDB: Float = 0
        var parametric: [ParametricEQBand] = []
        var dynamicEnabled = false
        var dynamic: [DynamicEQBand] = []
        var multiband = MultibandDynamicsConfiguration()
        var enhance = MonoEnhanceConfiguration.neutral
        var resetSerial: UInt64 = 0
    }

    private let configuration = RealtimeAudioConfiguration(Configuration())
    // Filter histories and ramps belong exclusively to the audio consumer.
    private var processor = EQFilterProcessor()
    private var standbyProcessor = EQFilterProcessor()
    private var applied = Configuration()
    private var desired = Configuration()
    private var standbyApplied = Configuration()
    private var transitionFramesRemaining = 0
    private var transitionFrameCount = 0
    private let transitionCapacity = 65_536
    private let transitionScratch = UnsafeMutablePointer<Float>.allocate(capacity: 65_536)

    public init() {}

    deinit { transitionScratch.deallocate() }

    public func setProcessingEnabled(_ enabled: Bool) {
        configuration.update { $0.enabled = enabled }
    }

    public func processingEnabled() -> Bool { configuration.read { $0.enabled } }
    public func currentGraphicMode() -> GraphicEQMode { configuration.read { $0.mode } }
    public func currentGraphicGains() -> [Float] { configuration.read { $0.gains } }

    public func setGraphicMode(_ mode: GraphicEQMode, gains: [Float]? = nil) {
        configuration.update { state in
            let previousMode = state.mode
            if mode != previousMode {
                state.calibration = mode.resampledGains(state.calibration, from: previousMode)
                state.adaptive = mode.resampledGains(state.adaptive, from: previousMode)
                state.hearingLeft = mode.resampledGains(state.hearingLeft, from: previousMode)
                state.hearingRight = mode.resampledGains(state.hearingRight, from: previousMode)
                state.gains = mode.resampledGains(state.gains, from: previousMode)
                state.mode = mode
            }
            if let gains {
                state.gains = Self.normalized(gains, mode: mode, limit: EQBandGain.maxGain)
            }
        }
    }

    @discardableResult
    public func setGraphicGain(_ gain: Float, at index: Int) -> Float? {
        configuration.update { state in
            guard state.gains.indices.contains(index) else { return nil }
            let clamped = EQBandGain.clamped(gain)
            state.gains[index] = clamped
            return clamped
        }
    }

    @discardableResult
    public func setGain(_ gain: Float, for band: EQBand) -> Float {
        configuration.update { state in
            let clamped = EQBandGain.clamped(gain)
            state.gains[Self.index(for: band, mode: state.mode)] = clamped
            return clamped
        }
    }

    public func gain(for band: EQBand) -> Float {
        configuration.read { $0.gains[Self.index(for: band, mode: $0.mode)] }
    }

    public func setCalibrationGains(_ gains: [Float]) {
        configuration.update { $0.calibration = Self.normalized(gains, mode: $0.mode, limit: 6) }
    }

    public func setAdaptiveGains(_ gains: [Float]) {
        configuration.update { $0.adaptive = Self.normalized(gains, mode: $0.mode, limit: 1.5) }
    }

    public func setHearingCorrection(left: [Float], right: [Float]) {
        configuration.update {
            $0.hearingLeft = Self.normalized(left, mode: $0.mode, limit: 6)
            $0.hearingRight = Self.normalized(right, mode: $0.mode, limit: 6)
        }
    }

    public func setPreampDB(_ gainDB: Float) {
        configuration.update { $0.preampDB = min(6, max(-24, gainDB.isFinite ? gainDB : 0)) }
    }

    public func setParametricBands(_ bands: [ParametricEQBand]) {
        configuration.update { $0.parametric = Array(bands.prefix(12)) }
    }

    public func setDynamicEQ(enabled: Bool, bands: [DynamicEQBand]) {
        configuration.update {
            $0.dynamicEnabled = enabled
            $0.dynamic = Array(bands.prefix(8))
        }
    }

    public func setMultibandDynamics(_ value: MultibandDynamicsConfiguration) {
        configuration.update { $0.multiband = value }
    }

    public func setMonoEnhance(_ value: MonoEnhanceConfiguration) {
        configuration.update { $0.enhance = EQFilterProcessor.sanitizedMonoEnhance(value) }
    }

    public func currentMonoEnhanceConfiguration() -> MonoEnhanceConfiguration {
        configuration.read { $0.enhance }
    }

    public func reset() {
        configuration.update {
            let zero = Array(repeating: Float(0), count: $0.mode.bandCount)
            $0.gains = zero
            $0.calibration = zero
            $0.adaptive = zero
            $0.hearingLeft = zero
            $0.hearingRight = zero
            $0.preampDB = 0
            $0.enhance = .neutral
            $0.resetSerial &+= 1
        }
    }

    /// Called by one audio consumer; control setters may run concurrently.
    public func process(_ buffer: AudioBuffer) -> AudioBuffer {
        guard buffer.frameCount > 0, buffer.channelCount > 0, buffer.sampleRate > 0 else { return buffer }
        if let next = configuration.takePending() { desired = next }
        if transitionFramesRemaining == 0 {
            if desired.mode != applied.mode {
                apply(desired, to: standbyProcessor, previous: standbyApplied, force: true)
                standbyProcessor.inheritPreampRamp(from: processor, target: desired.preampDB)
                standbyApplied = desired
                transitionFrameCount = max(1, buffer.sampleRate / 25)
                transitionFramesRemaining = transitionFrameCount
            } else if desired != applied {
                apply(desired, to: processor, previous: applied)
                applied = desired
            }
        }
        guard transitionFramesRemaining > 0 else { return processor.process(buffer) }

        // Only a layout handoff runs two preallocated native processors. New
        // writes coalesce in `desired` until this bounded 40 ms handoff ends.
        let chunkFrames = max(1, transitionCapacity / buffer.channelCount)
        var offset = 0
        while offset < buffer.frameCount {
            let frames = min(chunkFrames, buffer.frameCount - offset)
            let data = buffer.data.advanced(by: offset * buffer.channelCount)
            let chunk = AudioBuffer(data: data, frameCount: frames, channelCount: buffer.channelCount, sampleRate: buffer.sampleRate)
            if transitionFramesRemaining > 0 {
                transitionScratch.update(from: data, count: frames * buffer.channelCount)
                _ = processor.process(chunk)
                _ = standbyProcessor.process(AudioBuffer(
                    data: transitionScratch, frameCount: frames,
                    channelCount: buffer.channelCount, sampleRate: buffer.sampleRate
                ))
                let completed = transitionFrameCount - transitionFramesRemaining
                for frame in 0..<frames {
                    let progress = min(1, Float(completed + frame + 1) / Float(transitionFrameCount))
                    let mix = progress * progress * (3 - 2 * progress)
                    for channel in 0..<buffer.channelCount {
                        let index = frame * buffer.channelCount + channel
                        data[index] += (transitionScratch[index] - data[index]) * mix
                    }
                }
                transitionFramesRemaining = max(0, transitionFramesRemaining - frames)
                if transitionFramesRemaining == 0 {
                    swap(&processor, &standbyProcessor)
                    swap(&applied, &standbyApplied)
                }
            } else {
                _ = processor.process(chunk)
            }
            offset += frames
        }
        return buffer
    }

    private func apply(
        _ next: Configuration, to processor: EQFilterProcessor,
        previous applied: Configuration, force: Bool = false
    ) {
        let reset = force || next.resetSerial != applied.resetSerial
        if reset { processor.reset() }
        if reset || next.enabled != applied.enabled {
            processor.setProcessingEnabled(next.enabled)
        }
        if reset || next.mode != applied.mode || next.gains != applied.gains {
            processor.setGraphicMode(next.mode, gains: next.gains)
        }
        if reset || next.calibration != applied.calibration {
            processor.setCalibrationGains(next.calibration)
        }
        if reset || next.adaptive != applied.adaptive {
            processor.setAdaptiveGains(next.adaptive)
        }
        if reset || next.hearingLeft != applied.hearingLeft || next.hearingRight != applied.hearingRight {
            processor.setHearingCorrection(left: next.hearingLeft, right: next.hearingRight)
        }
        if reset || next.preampDB != applied.preampDB { processor.setPreampDB(next.preampDB) }
        if reset || next.parametric != applied.parametric { processor.setParametricBands(next.parametric) }
        if reset || next.dynamicEnabled != applied.dynamicEnabled || next.dynamic != applied.dynamic {
            processor.setDynamicEQ(enabled: next.dynamicEnabled, bands: next.dynamic)
        }
        if reset || next.multiband != applied.multiband { processor.setMultibandDynamics(next.multiband) }
        if reset || next.enhance != applied.enhance { processor.setMonoEnhance(next.enhance) }
    }

    private static func normalized(_ gains: [Float], mode: GraphicEQMode, limit: Float) -> [Float] {
        let source: GraphicEQMode = gains.count == 32 ? .thirtyTwoBand : .tenBand
        return mode.resampledGains(gains, from: source).map { min(limit, max(-limit, $0)) }
    }

    private static func index(for band: EQBand, mode: GraphicEQMode) -> Int {
        let frequencies = mode.centerFrequencies
        return frequencies.indices.min {
            abs(logf(frequencies[$0] / band.centerFrequency))
                < abs(logf(frequencies[$1] / band.centerFrequency))
        } ?? 0
    }
}

// No control-thread access: delays, envelopes and ramps remain continuous even
// when the UI is still preparing the next configuration.
private final class EQFilterProcessor {
    private var isProcessingEnabled = true

    private var graphicMode: GraphicEQMode = .tenBand
    private var userGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var calibrationGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var adaptiveGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var hearingLeftGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var hearingRightGains = Array(repeating: Float(0), count: GraphicEQMode.tenBand.bandCount)
    private var hearingSmoothedLeft = Array(repeating: Float(0), count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var hearingSmoothedRight = Array(repeating: Float(0), count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var hearingLeftCoefficients = Array(repeating: BiquadCoefficients.unity, count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var hearingRightCoefficients = Array(repeating: BiquadCoefficients.unity, count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var hearingLeftStates = Array(repeating: BiquadState(), count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var hearingRightStates = Array(repeating: BiquadState(), count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var smoothedGains = Array(repeating: Float(0), count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var graphicCoefficients = Array(repeating: BiquadCoefficients.unity, count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var graphicTargetCoefficients = Array(repeating: BiquadCoefficients.unity, count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var graphicTargetGains = Array(repeating: Float.nan, count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var graphicTargetSampleRates = Array(repeating: Float(0), count: GraphicEQMode.thirtyTwoBand.bandCount)
    private var graphicStates = (0..<GraphicEQMode.thirtyTwoBand.bandCount).map { _ in
        Array(repeating: BiquadState(), count: 2)
    }
    private let tenBandFrequencies = GraphicEQMode.tenBand.centerFrequencies
    private let thirtyTwoBandFrequencies = GraphicEQMode.thirtyTwoBand.centerFrequencies
    private let tenBandQValues = GraphicEQMode.tenBand.qValues
    private let thirtyTwoBandQValues = GraphicEQMode.thirtyTwoBand.qValues

    // Reuse runtime objects when configurations change; filter histories are
    // never copied or rebuilt by the control thread.
    private var parametricBands = (0..<12).map { _ in
        ParametricRuntimeBand(configuration: ParametricEQBand(isEnabled: false))
    }
    private var parametricScratch = (0..<12).map { _ in
        ParametricRuntimeBand(configuration: ParametricEQBand(isEnabled: false))
    }
    private var parametricBandCount = 0
    private var dynamicBands = (0..<8).map { _ in
        DynamicRuntimeBand(configuration: DynamicEQBand.monoDefaults[0])
    }
    private var dynamicScratch = (0..<8).map { _ in
        DynamicRuntimeBand(configuration: DynamicEQBand.monoDefaults[0])
    }
    private var dynamicBandCount = 0
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

    init() {
        // Warm the immutable gain table outside the realtime callback.
        _ = Self.decibelGainLookup.count
        resetGraphicRuntime()
        multibandStates = Array(repeating: MultibandChannelState(), count: 2)
        multibandFrameValues = Array(repeating: 0, count: 6)
        monoEnhanceChannelStates = Array(repeating: MonoEnhanceChannelState(), count: 2)
        monoEnhanceFrameValues = Array(repeating: 0, count: 6)
    }

    func setProcessingEnabled(_ enabled: Bool) {
        isProcessingEnabled = enabled
    }

    func setGraphicMode(_ mode: GraphicEQMode, gains: [Float]) {
        if mode != graphicMode {
            graphicMode = mode
            resetGraphicRuntime()
            resetHearingRuntime()
        }
        userGains = gains
    }

    func setCalibrationGains(_ gains: [Float]) { calibrationGains = gains }
    func setAdaptiveGains(_ gains: [Float]) { adaptiveGains = gains }

    func setHearingCorrection(left: [Float], right: [Float]) {
        hearingLeftGains = left
        hearingRightGains = right
    }

    func setPreampDB(_ gainDB: Float) {
        let target = min(max(gainDB, -24), 6)
        if abs(target - targetPreampDB) > 0.002 {
            targetPreampDB = target
            preampRampPending = true
        }
    }

    func inheritPreampRamp(from source: EQFilterProcessor, target: Float) {
        targetPreampDB = source.targetPreampDB
        currentPreampDB = source.currentPreampDB
        preampRampStartDB = source.preampRampStartDB
        preampRampProcessedFrames = source.preampRampProcessedFrames
        preampRampTotalFrames = source.preampRampTotalFrames
        preampRampPending = source.preampRampPending
        setPreampDB(target)
    }

    func setParametricBands(_ bands: [ParametricEQBand]) {
        var reusedMask = 0
        for index in bands.indices {
            let configuration = bands[index]
            var match: Int?
            var nearestDistance: Float = 0.18
            for oldIndex in 0..<parametricBandCount where reusedMask & (1 << oldIndex) == 0 {
                let old = parametricBands[oldIndex].configuration
                if old.id == configuration.id {
                    match = oldIndex
                    break
                }
                guard old.type == configuration.type else { continue }
                let distance = abs(log2f(max(configuration.frequency, 1) / max(old.frequency, 1)))
                if distance < nearestDistance {
                    nearestDistance = distance
                    match = oldIndex
                }
            }
            if let match {
                reusedMask |= 1 << match
                swap(&parametricScratch[index], &parametricBands[match])
            } else {
                parametricScratch[index].reset()
            }
            let runtime = parametricScratch[index]
            if runtime.configuration != configuration { runtime.targetCoefficientSampleRate = 0 }
            runtime.configuration = configuration
        }
        swap(&parametricBands, &parametricScratch)
        parametricBandCount = bands.count
    }

    func setDynamicEQ(enabled: Bool, bands: [DynamicEQBand]) {
        var reusedMask = 0
        for index in bands.indices {
            let configuration = bands[index]
            var match: Int?
            var nearestDistance: Float = 0.18
            for oldIndex in 0..<dynamicBandCount where reusedMask & (1 << oldIndex) == 0 {
                let old = dynamicBands[oldIndex].configuration
                if old.id == configuration.id {
                    match = oldIndex
                    break
                }
                let distance = abs(log2f(max(configuration.frequency, 1) / max(old.frequency, 1)))
                if distance < nearestDistance {
                    nearestDistance = distance
                    match = oldIndex
                }
            }
            if let match {
                reusedMask |= 1 << match
                swap(&dynamicScratch[index], &dynamicBands[match])
            } else {
                dynamicScratch[index].reset()
            }
            let runtime = dynamicScratch[index]
            if runtime.configuration != configuration { runtime.detectorCoefficientSampleRate = 0 }
            runtime.configuration = configuration
        }
        swap(&dynamicBands, &dynamicScratch)
        dynamicBandCount = bands.count
        dynamicEQEnabled = enabled
    }

    func setMultibandDynamics(_ configuration: MultibandDynamicsConfiguration) {
        if multiband != configuration {
            multibandCoefficientSampleRate = 0
            multibandControlFramesRemaining = 0
        }
        multiband = configuration
    }

    func setMonoEnhance(_ configuration: MonoEnhanceConfiguration) {
        targetMonoEnhance = configuration
    }

    func reset() {
        resetGraphicRuntime()
        resetHearingRuntime()
        targetPreampDB = 0
        currentPreampDB = 0
        preampRampStartDB = 0
        preampRampProcessedFrames = 0
        preampRampTotalFrames = 0
        preampRampPending = false
        targetMonoEnhance = .neutral
        currentMonoEnhance = .neutral
        resetRuntimeStates()
    }

    /// In-place processing on the single audio consumer.
    func process(_ buffer: AudioBuffer) -> AudioBuffer {
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
        processHearingCorrection(data, frames: frameCount, channels: channelCount, sampleRate: sampleRate)
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
        let frequencies = graphicMode == .tenBand ? tenBandFrequencies : thirtyTwoBandFrequencies
        let qValues = graphicMode == .tenBand ? tenBandQValues : thirtyTwoBandQValues
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
            let previousCoefficients = graphicCoefficients[index]
            graphicCoefficients[index] = .interpolate(
                graphicCoefficients[index],
                graphicTargetCoefficients[index],
                t: 0.35
            )
            if abs(target) < 0.005,
               abs(gain) < 0.005,
               Self.isNearUnity(graphicCoefficients[index]) {
                graphicCoefficients[index] = .unity
                for channel in graphicStates[index].indices { graphicStates[index][channel].reset() }
                continue
            }
            ensureStateCount(&graphicStates[index], channels: channels)
            processBiquad(
                data,
                frames: frames,
                channels: channels,
                coefficients: graphicCoefficients[index],
                initialCoefficients: previousCoefficients,
                states: &graphicStates[index]
            )
        }
    }

    private func processParametricEQ(
        _ data: UnsafeMutablePointer<Float>, frames: Int, channels: Int, sampleRate: Float
    ) {
        for index in 0..<parametricBandCount where parametricBands[index].configuration.isEnabled {
            let configuration = parametricBands[index].configuration
            if abs(parametricBands[index].targetCoefficientSampleRate - sampleRate) > 1 {
                parametricBands[index].targetCoefficients = coefficients(
                    for: configuration,
                    sampleRate: sampleRate
                )
                parametricBands[index].targetCoefficientSampleRate = sampleRate
            }
            let previousCoefficients = parametricBands[index].coefficients
            parametricBands[index].coefficients = .interpolate(
                parametricBands[index].coefficients,
                parametricBands[index].targetCoefficients,
                t: 0.28
            )
            if configuration.type.usesGain,
               abs(configuration.gainDB) < 0.005,
               Self.isNearUnity(parametricBands[index].coefficients) {
                parametricBands[index].coefficients = .unity
                for channel in parametricBands[index].states.indices { parametricBands[index].states[channel].reset() }
                continue
            }
            ensureStateCount(&parametricBands[index].states, channels: channels)
            processBiquad(
                data,
                frames: frames,
                channels: channels,
                coefficients: parametricBands[index].coefficients,
                initialCoefficients: previousCoefficients,
                states: &parametricBands[index].states
            )
        }
    }

    private func processHearingCorrection(
        _ data: UnsafeMutablePointer<Float>, frames: Int, channels: Int, sampleRate: Float
    ) {
        guard channels >= 2 else { return }
        guard hearingLeftGains.contains(where: { abs($0) >= 0.005 })
                || hearingRightGains.contains(where: { abs($0) >= 0.005 })
                || hearingSmoothedLeft.contains(where: { abs($0) >= 0.005 })
                || hearingSmoothedRight.contains(where: { abs($0) >= 0.005 }) else {
            return
        }
        let frequencies = graphicMode == .tenBand ? tenBandFrequencies : thirtyTwoBandFrequencies
        let qValues = graphicMode.qValues
        guard hearingLeftGains.count == frequencies.count,
              hearingRightGains.count == frequencies.count else { return }

        for index in frequencies.indices {
            let leftTarget = hearingLeftGains[index]
            let rightTarget = hearingRightGains[index]
            hearingSmoothedLeft[index] += (leftTarget - hearingSmoothedLeft[index]) * 0.06
            hearingSmoothedRight[index] += (rightTarget - hearingSmoothedRight[index]) * 0.06
            let previousLeft = hearingLeftCoefficients[index]
            let previousRight = hearingRightCoefficients[index]
            hearingLeftCoefficients[index] = .interpolate(
                hearingLeftCoefficients[index],
                hearingCoefficient(
                    gainDB: hearingSmoothedLeft[index],
                    index: index,
                    frequencies: frequencies,
                    qValues: qValues,
                    sampleRate: sampleRate
                ),
                t: 0.28
            )
            hearingRightCoefficients[index] = .interpolate(
                hearingRightCoefficients[index],
                hearingCoefficient(
                    gainDB: hearingSmoothedRight[index],
                    index: index,
                    frequencies: frequencies,
                    qValues: qValues,
                    sampleRate: sampleRate
                ),
                t: 0.28
            )

            var leftState = hearingLeftStates[index]
            var rightState = hearingRightStates[index]
            let leftCoefficients = hearingLeftCoefficients[index]
            let rightCoefficients = hearingRightCoefficients[index]
            for frame in 0..<frames {
                let progress = Float(frame + 1) / Float(frames)
                let leftC = BiquadCoefficients.interpolate(previousLeft, leftCoefficients, t: progress)
                let rightC = BiquadCoefficients.interpolate(previousRight, rightCoefficients, t: progress)
                let leftIndex = frame * channels
                let leftInput = data[leftIndex]
                data[leftIndex] = leftState.process(leftInput, coefficients: leftC)

                let rightIndex = leftIndex + 1
                let rightInput = data[rightIndex]
                data[rightIndex] = rightState.process(rightInput, coefficients: rightC)
            }
            hearingLeftStates[index] = leftState
            hearingRightStates[index] = rightState
        }
    }

    private func hearingCoefficient(
        gainDB: Float,
        index: Int,
        frequencies: [Float],
        qValues: [Float],
        sampleRate: Float
    ) -> BiquadCoefficients {
        guard abs(gainDB) >= 0.005 else { return .unity }
        if graphicMode == .tenBand, index == frequencies.startIndex {
            return .lowShelf(gainDB: gainDB, frequency: frequencies[index], sampleRate: sampleRate)
        }
        if graphicMode == .tenBand, index == frequencies.index(before: frequencies.endIndex) {
            return .highShelf(gainDB: gainDB, frequency: frequencies[index], sampleRate: sampleRate)
        }
        return .peakingEQ(
            gainDB: gainDB,
            centerFrequency: frequencies[index],
            sampleRate: sampleRate,
            q: qValues[index]
        )
    }

    private func processDynamicEQ(
        _ data: UnsafeMutablePointer<Float>, frames: Int, channels: Int, sampleRate: Float
    ) {
        guard dynamicEQEnabled else { return }
        let sampleCount = max(frames * channels, 1)

        for index in 0..<dynamicBandCount where dynamicBands[index].configuration.isEnabled {
            let configuration = dynamicBands[index].configuration
            let previousDetector = dynamicBands[index].detectorCoefficients
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
                var state = dynamicBands[index].detectorStates[channel]
                let c = dynamicBands[index].detectorCoefficients
                for frame in 0..<frames {
                    let sample = data[frame * channels + channel]
                    let current = previousDetector == c ? c : BiquadCoefficients.interpolate(
                        previousDetector, c, t: Float(frame + 1) / Float(frames)
                    )
                    let output = state.process(sample, coefficients: current)
                    energy += output * output
                }
                dynamicBands[index].detectorStates[channel] = state
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
            let previousCoefficients = dynamicBands[index].processingCoefficients
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
                initialCoefficients: previousCoefficients,
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
        initialCoefficients: BiquadCoefficients? = nil,
        states: inout [BiquadState]
    ) {
        let start = initialCoefficients ?? c
        let isRamping = start != c
        for channel in 0..<channels {
            var state = states[channel]
            for frame in 0..<frames {
                let index = frame * channels + channel
                let current = isRamping ? BiquadCoefficients.interpolate(
                    start, c, t: Float(frame + 1) / Float(frames)
                ) : c
                data[index] = state.process(data[index], coefficients: current)
            }
            states[channel] = state
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

    static func sanitizedMonoEnhance(
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
        resetGraphicRuntime()
        resetHearingRuntime()
        for runtime in parametricBands { runtime.reset() }
        for runtime in dynamicBands { runtime.reset() }
        for index in multibandStates.indices { multibandStates[index] = MultibandChannelState() }
        for index in multibandFrameValues.indices { multibandFrameValues[index] = 0 }
        for index in multibandEnvelopes.indices { multibandEnvelopes[index] = 0 }
        for index in multibandCurrentGains.indices { multibandCurrentGains[index] = 1 }
        for index in multibandGainSteps.indices { multibandGainSteps[index] = 0 }
        multibandControlFramesRemaining = 0
        multibandCoefficientSampleRate = 0
        for index in monoEnhanceChannelStates.indices { monoEnhanceChannelStates[index] = MonoEnhanceChannelState() }
        for index in monoEnhanceFrameValues.indices { monoEnhanceFrameValues[index] = 0 }
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

    private func resetGraphicRuntime() {
        for index in smoothedGains.indices {
            smoothedGains[index] = 0
            graphicCoefficients[index] = .unity
            graphicTargetCoefficients[index] = .unity
            graphicTargetGains[index] = .nan
            graphicTargetSampleRates[index] = 0
            for channel in graphicStates[index].indices { graphicStates[index][channel].reset() }
        }
    }

    private func resetHearingRuntime() {
        for index in hearingSmoothedLeft.indices {
            hearingSmoothedLeft[index] = 0
            hearingSmoothedRight[index] = 0
            hearingLeftCoefficients[index] = .unity
            hearingRightCoefficients[index] = .unity
            hearingLeftStates[index].reset()
            hearingRightStates[index].reset()
        }
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
