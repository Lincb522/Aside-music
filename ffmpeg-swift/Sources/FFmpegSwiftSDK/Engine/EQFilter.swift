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
    var states: [BiquadState] = []
}

private struct DynamicRuntimeBand {
    var configuration: DynamicEQBand
    var detectorCoefficients: BiquadCoefficients = .unity
    var detectorStates: [BiquadState] = []
    var processingCoefficients: BiquadCoefficients = .unity
    var processingStates: [BiquadState] = []
    var reductionDB: Float = 0
}

private struct MultibandChannelState {
    var low: Float = 0
    var highLowPass: Float = 0
}

// MARK: - EQFilter

public final class EQFilter {
    private let lock = NSLock()
    private var isProcessingEnabled = true

    private var userGains = Array(repeating: Float(0), count: EQBand.allCases.count)
    private var calibrationGains = Array(repeating: Float(0), count: EQBand.allCases.count)
    private var adaptiveGains = Array(repeating: Float(0), count: EQBand.allCases.count)
    private var smoothedGains = Array(repeating: Float(0), count: EQBand.allCases.count)
    private var graphicCoefficients = Array(repeating: BiquadCoefficients.unity, count: EQBand.allCases.count)
    private var graphicStates = Array(repeating: [BiquadState](), count: EQBand.allCases.count)

    private var parametricBands: [ParametricRuntimeBand] = []
    private var dynamicBands: [DynamicRuntimeBand] = []
    private var dynamicEQEnabled = false

    private var multiband = MultibandDynamicsConfiguration()
    private var multibandStates: [MultibandChannelState] = []
    private var multibandEnvelopes = Array(repeating: Float(0), count: 3)
    private var multibandFrameValues: [Float] = []

    private var targetPreampDB: Float = 0
    private var currentPreampDB: Float = 0
    private var lastSampleRate: Float = 44_100

    public init() {}

    public func setProcessingEnabled(_ enabled: Bool) {
        lock.lock()
        isProcessingEnabled = enabled
        lock.unlock()
    }

    @discardableResult
    public func setGain(_ gain: Float, for band: EQBand) -> Float {
        let clamped = EQBandGain.clamped(gain)
        lock.lock()
        let index = band.rawValue
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
        return userGains[band.rawValue]
    }

    public func setCalibrationGains(_ gains: [Float]) {
        lock.lock()
        calibrationGains = Self.normalizedGains(gains, limit: 6)
        lock.unlock()
    }

    public func setAdaptiveGains(_ gains: [Float]) {
        lock.lock()
        adaptiveGains = Self.normalizedGains(gains, limit: 1.5)
        lock.unlock()
    }

    public func setPreampDB(_ gainDB: Float) {
        lock.lock()
        targetPreampDB = min(max(gainDB, -24), 6)
        lock.unlock()
    }

    public func setParametricBands(_ bands: [ParametricEQBand]) {
        lock.lock()
        let previous = parametricBands
        parametricBands = bands.prefix(12).map { configuration in
            if var runtime = previous.first(where: { $0.configuration.id == configuration.id }) {
                runtime.configuration = configuration
                return runtime
            }
            return ParametricRuntimeBand(configuration: configuration)
        }
        lock.unlock()
    }

    public func setDynamicEQ(enabled: Bool, bands: [DynamicEQBand]) {
        lock.lock()
        dynamicEQEnabled = enabled
        let previous = dynamicBands
        dynamicBands = bands.prefix(6).map { configuration in
            if var runtime = previous.first(where: { $0.configuration.id == configuration.id }) {
                runtime.configuration = configuration
                return runtime
            }
            return DynamicRuntimeBand(configuration: configuration)
        }
        lock.unlock()
    }

    public func setMultibandDynamics(_ configuration: MultibandDynamicsConfiguration) {
        lock.lock()
        multiband = configuration
        lock.unlock()
    }

    public func reset() {
        lock.lock()
        userGains = Array(repeating: 0, count: EQBand.allCases.count)
        calibrationGains = Array(repeating: 0, count: EQBand.allCases.count)
        adaptiveGains = Array(repeating: 0, count: EQBand.allCases.count)
        smoothedGains = Array(repeating: 0, count: EQBand.allCases.count)
        graphicCoefficients = Array(repeating: .unity, count: EQBand.allCases.count)
        graphicStates = Array(repeating: [], count: EQBand.allCases.count)
        targetPreampDB = 0
        currentPreampDB = 0
        resetRuntimeStates()
        lock.unlock()
    }

    /// In-place realtime processing. The audio callback never waits for UI
    /// configuration; it skips one block if a setting is being committed.
    public func process(_ buffer: AudioBuffer) -> AudioBuffer {
        guard lock.try() else { return buffer }
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
        applyPreamp(data, sampleCount: frameCount * channelCount)
        return buffer
    }

    private func processGraphicEQ(
        _ data: UnsafeMutablePointer<Float>, frames: Int, channels: Int, sampleRate: Float
    ) {
        for band in EQBand.allCases {
            let index = band.rawValue
            let target = min(max(userGains[index] + calibrationGains[index] + adaptiveGains[index], -18), 18)
            let current = smoothedGains[index]
            smoothedGains[index] = abs(target - current) < 0.005
                ? target
                : current + (target - current) * 0.08

            let gain = smoothedGains[index]
            let targetCoefficients: BiquadCoefficients
            if abs(gain) < 0.005 {
                targetCoefficients = .unity
            } else if band == .hz31 {
                targetCoefficients = .lowShelf(gainDB: gain, frequency: band.centerFrequency, sampleRate: sampleRate)
            } else if band == .hz16k {
                targetCoefficients = .highShelf(gainDB: gain, frequency: band.centerFrequency, sampleRate: sampleRate)
            } else {
                targetCoefficients = .peakingEQ(
                    gainDB: gain,
                    centerFrequency: band.centerFrequency,
                    sampleRate: sampleRate,
                    q: band.q
                )
            }
            graphicCoefficients[index] = .interpolate(graphicCoefficients[index], targetCoefficients, t: 0.35)
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
            let target = coefficients(for: configuration, sampleRate: sampleRate)
            parametricBands[index].coefficients = .interpolate(
                parametricBands[index].coefficients,
                target,
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
            dynamicBands[index].detectorCoefficients = .bandPass(
                frequency: configuration.frequency,
                sampleRate: sampleRate,
                q: configuration.q
            )
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

        let lowAlpha = 1 - expf(-2 * Float.pi * multiband.lowCrossoverHz / sampleRate)
        let highAlpha = 1 - expf(-2 * Float.pi * multiband.highCrossoverHz / sampleRate)
        let attackCoefficient = expf(-1 / (max(multiband.attackMS, 1) * 0.001 * sampleRate))
        let releaseCoefficient = expf(-1 / (max(multiband.releaseMS, 1) * 0.001 * sampleRate))

        for frame in 0..<frames {
            var peakLow: Float = 0
            var peakMid: Float = 0
            var peakHigh: Float = 0
            for channel in 0..<channels {
                let index = frame * channels + channel
                let input = data[index]
                multibandStates[channel].low += lowAlpha * (input - multibandStates[channel].low)
                multibandStates[channel].highLowPass += highAlpha * (input - multibandStates[channel].highLowPass)
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

            var gains = (Float(1), Float(1), Float(1))
            for band in 0..<3 {
                let detector: Float
                switch band {
                case 0: detector = peakLow
                case 1: detector = peakMid
                default: detector = peakHigh
                }
                let coefficient = detector > multibandEnvelopes[band] ? attackCoefficient : releaseCoefficient
                multibandEnvelopes[band] = coefficient * multibandEnvelopes[band] + (1 - coefficient) * detector
                let levelDB = 20 * log10f(max(multibandEnvelopes[band], 0.000_001))
                let excess = max(0, levelDB - multiband.thresholdsDB[band])
                let reduction = min(
                    multiband.maxReductionDB[band],
                    excess * (1 - 1 / multiband.ratios[band])
                )
                let gain = powf(10, -reduction / 20)
                switch band {
                case 0: gains.0 = gain
                case 1: gains.1 = gain
                default: gains.2 = gain
                }
            }

            for channel in 0..<channels {
                let values = channel * 3
                data[frame * channels + channel] =
                    multibandFrameValues[values] * gains.0
                    + multibandFrameValues[values + 1] * gains.1
                    + multibandFrameValues[values + 2] * gains.2
            }
        }
    }

    private func applyPreamp(_ data: UnsafeMutablePointer<Float>, sampleCount: Int) {
        let start = currentPreampDB
        let end = abs(targetPreampDB - start) < 0.002
            ? targetPreampDB
            : start + (targetPreampDB - start) * 0.12
        guard abs(start) > 0.000_1 || abs(end) > 0.000_1 else {
            currentPreampDB = end
            return
        }
        let denominator = Float(max(sampleCount - 1, 1))
        for index in 0..<sampleCount {
            let progress = Float(index) / denominator
            let gainDB = start + (end - start) * progress
            data[index] *= powf(10, gainDB / 20)
        }
        currentPreampDB = end
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

    private func resetRuntimeStates() {
        graphicStates = Array(repeating: [], count: EQBand.allCases.count)
        for index in parametricBands.indices {
            parametricBands[index].states = []
            parametricBands[index].coefficients = .unity
        }
        for index in dynamicBands.indices {
            dynamicBands[index].detectorStates = []
            dynamicBands[index].processingStates = []
            dynamicBands[index].detectorCoefficients = .unity
            dynamicBands[index].processingCoefficients = .unity
            dynamicBands[index].reductionDB = 0
        }
        multibandStates = []
        multibandFrameValues = []
        multibandEnvelopes = Array(repeating: 0, count: 3)
    }

    private static func normalizedGains(_ gains: [Float], limit: Float) -> [Float] {
        var output = Array(repeating: Float(0), count: EQBand.allCases.count)
        for index in 0..<min(gains.count, output.count) {
            output[index] = min(max(gains[index], -limit), limit)
        }
        return output
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
