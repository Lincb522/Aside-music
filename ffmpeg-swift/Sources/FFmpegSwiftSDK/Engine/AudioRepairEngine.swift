// AudioRepairEngine.swift
// FFmpegSwiftSDK
//
// 音频修复引擎：在所有音效处理之后、输出到硬件之前，
// 自动检测并修复各种音频问题。

import Foundation
import Accelerate

/// 音频修复引擎
public final class AudioRepairEngine {

    // MARK: - 修复模块开关

    public var isDeclipEnabled: Bool = false
    public var isDenoiseEnabled: Bool = false
    public var isGapSmoothingEnabled: Bool = false
    public var isOverlapRemovalEnabled: Bool = false
    public var isPopRemovalEnabled: Bool = false
    public var isSoftLimiterEnabled: Bool = false
    public var isDitherEnabled: Bool = false
    public var isFadeInProtectionEnabled: Bool = false
    public var isLoudnessStabilizerEnabled: Bool = false
    public var isReverbTailGuardEnabled: Bool = false
    public var isPhaseContinuityEnabled: Bool = false
    public var isFilterTransitionEnabled: Bool = false

    public var isActive: Bool {
        return isDeclipEnabled || isDenoiseEnabled || isGapSmoothingEnabled ||
               isOverlapRemovalEnabled || isPopRemovalEnabled || isSoftLimiterEnabled ||
               isDitherEnabled || isFadeInProtectionEnabled ||
               isLoudnessStabilizerEnabled || isReverbTailGuardEnabled ||
               isPhaseContinuityEnabled || isFilterTransitionEnabled
    }

    // MARK: - 可调参数

    public var clipThreshold: Float = 0.98
    public var popSensitivity: Float = 0.3
    public var limiterThreshold: Float = 0.95
    public var fadeInSamples: Int = 256
    public var loudnessSmoothing: Float = 0.15
    public var loudnessJumpThreshold: Float = 12.0  // 12dB，只有非常剧烈的变化才触发
    public var filterTransitionMaxSamples: Int = 1024
    public var reverbTailHistoryLength: Int = 4096

    // MARK: - 内部状态

    private let lock = NSLock()
    private var dcFilterState: [DCBlockerState] = []
    private var previousTail: [Float] = []
    private let tailLength: Int = 64
    private var lastSamples: [Float] = []
    private var fadeInCounter: Int = 0
    private var fadeInActive: Bool = true
    private var ditherState: Float = 0
    private var frameCount: Int64 = 0

    // 响度突变抑制状态
    private var rmsEnvelope: Float = 0
    private var loudnessGain: Float = 1.0
    private var previousRMS: Float = 0
    private var loudnessSmoothRemaining: Int = 0
    private var loudnessSmoothStartGain: Float = 1.0

    // 混响尾音保护状态
    private var reverbHistory: [Float] = []
    private var reverbHistoryWritePos: Int = 0
    private var reverbHistoryChannels: Int = 0
    private var reverbTailActive: Bool = false
    private var reverbTailRemaining: Int = 0

    // 相位连续性状态
    private var previousPhaseDirection: [Float] = []

    // 滤镜重建过渡状态
    private var transitionBuffer: [Float] = []
    private var transitionRemaining: Int = 0
    private var transitionLength: Int = 0
    private var prevFrameRMS: Float = 0
    private var stableFrameCount: Int = 0

    private var stats = RepairStats()

    private struct DCBlockerState {
        var xPrev: Float = 0
        var yPrev: Float = 0
    }

    // MARK: - 修复统计

    public struct RepairStats {
        public var clippedSamplesRepaired: Int = 0
        public var popsRemoved: Int = 0
        public var gapsFilled: Int = 0
        public var overlapsFixed: Int = 0
        public var limiterActivations: Int = 0
        public var loudnessJumpsSmoothed: Int = 0
        public var reverbTailsFilled: Int = 0
        public var phaseFlipsFixed: Int = 0
        public var filterTransitions: Int = 0
        public var totalFramesProcessed: Int64 = 0
    }

    public var repairStats: RepairStats {
        lock.lock()
        let s = stats
        lock.unlock()
        return s
    }

    public func resetStats() {
        lock.lock()
        stats = RepairStats()
        lock.unlock()
    }

    // MARK: - 初始化

    public init() {}

    // MARK: - 一键操作

    public func enableAll() {
        isDeclipEnabled = true
        isDenoiseEnabled = true
        isGapSmoothingEnabled = true
        isOverlapRemovalEnabled = true
        isPopRemovalEnabled = true
        isSoftLimiterEnabled = true
        isDitherEnabled = true
        isFadeInProtectionEnabled = true
        isLoudnessStabilizerEnabled = true
        isReverbTailGuardEnabled = true
        isPhaseContinuityEnabled = true
        isFilterTransitionEnabled = true
    }

    public func disableAll() {
        isDeclipEnabled = false
        isDenoiseEnabled = false
        isGapSmoothingEnabled = false
        isOverlapRemovalEnabled = false
        isPopRemovalEnabled = false
        isSoftLimiterEnabled = false
        isDitherEnabled = false
        isFadeInProtectionEnabled = false
        isLoudnessStabilizerEnabled = false
        isReverbTailGuardEnabled = false
        isPhaseContinuityEnabled = false
        isFilterTransitionEnabled = false
    }

    public func reset() {
        lock.lock()
        dcFilterState.removeAll()
        previousTail.removeAll()
        lastSamples.removeAll()
        fadeInCounter = 0
        fadeInActive = true
        ditherState = 0
        frameCount = 0
        rmsEnvelope = 0
        loudnessGain = 1.0
        previousRMS = 0
        loudnessSmoothRemaining = 0
        loudnessSmoothStartGain = 1.0
        reverbHistory.removeAll()
        reverbHistoryWritePos = 0
        reverbHistoryChannels = 0
        reverbTailActive = false
        reverbTailRemaining = 0
        previousPhaseDirection.removeAll()
        transitionBuffer.removeAll()
        transitionRemaining = 0
        transitionLength = 0
        prevFrameRMS = 0
        stableFrameCount = 0
        lock.unlock()
    }

    // MARK: - 核心处理

    public func process(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int,
        sampleRate: Int
    ) {
        guard isActive, frameCount > 0, channelCount > 0 else { return }

        let totalSamples = frameCount * channelCount

        guard lock.try() else { return }

        ensureStateSize(channelCount: channelCount)
        self.frameCount += Int64(frameCount)

        // 修复流水线（顺序很重要）

        if isFadeInProtectionEnabled {
            applyFadeInProtection(data, totalSamples: totalSamples, channelCount: channelCount)
        }
        if isFilterTransitionEnabled {
            applyFilterTransition(data, frameCount: frameCount, channelCount: channelCount)
        }
        if isLoudnessStabilizerEnabled {
            applyLoudnessStabilizer(data, frameCount: frameCount, channelCount: channelCount)
        }
        if isDenoiseEnabled {
            applyDCBlocker(data, frameCount: frameCount, channelCount: channelCount)
        }
        if isPhaseContinuityEnabled {
            applyPhaseContinuity(data, frameCount: frameCount, channelCount: channelCount)
        }
        if isPopRemovalEnabled {
            applyPopRemoval(data, frameCount: frameCount, channelCount: channelCount)
        }
        if isGapSmoothingEnabled {
            applyGapSmoothing(data, frameCount: frameCount, channelCount: channelCount)
        }
        if isReverbTailGuardEnabled {
            applyReverbTailGuard(data, frameCount: frameCount, channelCount: channelCount)
        }
        if isOverlapRemovalEnabled {
            applyOverlapRemoval(data, frameCount: frameCount, channelCount: channelCount)
        }
        if isDeclipEnabled {
            applyDeclip(data, frameCount: frameCount, channelCount: channelCount)
        }
        if isDenoiseEnabled {
            applyUltrasonicFilter(data, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        }
        if isSoftLimiterEnabled {
            applySoftLimiter(data, totalSamples: totalSamples)
        }
        if isDitherEnabled {
            applyDither(data, totalSamples: totalSamples)
        }
        if isReverbTailGuardEnabled {
            updateReverbHistory(data, frameCount: frameCount, channelCount: channelCount)
        }

        saveTail(data, frameCount: frameCount, channelCount: channelCount)
        stats.totalFramesProcessed += Int64(frameCount)

        lock.unlock()
    }

    // MARK: - 状态管理

    private func ensureStateSize(channelCount: Int) {
        if dcFilterState.count != channelCount {
            dcFilterState = Array(repeating: DCBlockerState(), count: channelCount)
        }
        if lastSamples.count != channelCount {
            lastSamples = Array(repeating: 0, count: channelCount)
        }
    }

    private func saveTail(_ data: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        let samplesToSave = min(tailLength, frameCount) * channelCount
        let startIdx = (frameCount - min(tailLength, frameCount)) * channelCount
        previousTail = Array(UnsafeBufferPointer(start: data + startIdx, count: samplesToSave))
    }

    // MARK: - 1. 淡入保护

    private func applyFadeInProtection(
        _ data: UnsafeMutablePointer<Float>,
        totalSamples: Int,
        channelCount: Int
    ) {
        guard fadeInActive else { return }
        let totalFrames = totalSamples / channelCount
        for frame in 0..<totalFrames {
            if fadeInCounter >= fadeInSamples {
                fadeInActive = false
                break
            }
            let t = Float(fadeInCounter) / Float(fadeInSamples)
            let gain = t * t * (3.0 - 2.0 * t)
            for ch in 0..<channelCount {
                data[frame * channelCount + ch] *= gain
            }
            fadeInCounter += 1
        }
    }

    // MARK: - 2. DC 偏移消除

    private func applyDCBlocker(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int
    ) {
        let R: Float = 0.9975
        for ch in 0..<channelCount {
            var xPrev = dcFilterState[ch].xPrev
            var yPrev = dcFilterState[ch].yPrev
            for frame in 0..<frameCount {
                let idx = frame * channelCount + ch
                let x = data[idx]
                let y = x - xPrev + R * yPrev
                data[idx] = y
                xPrev = x
                yPrev = y
            }
            dcFilterState[ch].xPrev = xPrev
            dcFilterState[ch].yPrev = yPrev
        }
    }

    // MARK: - 3. 爆音检测与修复

    private func applyPopRemoval(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int
    ) {
        for ch in 0..<channelCount {
            var prev = lastSamples[ch]
            for frame in 0..<frameCount {
                let idx = frame * channelCount + ch
                let current = data[idx]
                let diff = abs(current - prev)
                if diff > popSensitivity {
                    if frame > 0 && frame < frameCount - 1 {
                        let prevSample = data[(frame - 1) * channelCount + ch]
                        let nextSample = data[(frame + 1) * channelCount + ch]
                        data[idx] = median3(prevSample, current, nextSample)
                    } else if frame == 0 {
                        data[idx] = prev * 0.7 + current * 0.3
                    }
                    stats.popsRemoved += 1
                }
                prev = data[idx]
            }
            lastSamples[ch] = prev
        }
    }

    private func median3(_ a: Float, _ b: Float, _ c: Float) -> Float {
        if a > b {
            if b > c { return b }
            else if a > c { return c }
            else { return a }
        } else {
            if a > c { return a }
            else if b > c { return c }
            else { return b }
        }
    }

    // MARK: - 4. 卡顿平滑

    private func applyGapSmoothing(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int
    ) {
        let checkSamples = min(32, frameCount)
        var maxAbs: Float = 0
        for i in 0..<(checkSamples * channelCount) {
            maxAbs = max(maxAbs, abs(data[i]))
        }
        let silenceThreshold: Float = 0.0001
        if maxAbs < silenceThreshold && !previousTail.isEmpty {
            let tailFrames = previousTail.count / channelCount
            let fadeFrames = min(tailFrames, min(32, frameCount))
            for frame in 0..<fadeFrames {
                let fadeOut = Float(fadeFrames - frame) / Float(fadeFrames)
                let tailFrame = tailFrames - fadeFrames + frame
                for ch in 0..<channelCount {
                    let tailIdx = tailFrame * channelCount + ch
                    let dataIdx = frame * channelCount + ch
                    if tailIdx < previousTail.count {
                        data[dataIdx] = previousTail[tailIdx] * fadeOut * 0.5
                    }
                }
            }
            stats.gapsFilled += 1
        }
    }

    // MARK: - 5. 重叠消除

    /// 检测真正的帧重叠（相同数据被发送两次）
    /// 只有当前帧开头与上一帧尾部几乎完全相同时才触发
    private func applyOverlapRemoval(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int
    ) {
        guard !previousTail.isEmpty else { return }
        let tailFrames = previousTail.count / channelCount
        let compareFrames = min(16, min(tailFrames, frameCount))
        
        // 计算差异而非相关性 - 真正的重叠意味着数据几乎完全相同
        var totalDiff: Float = 0
        var totalEnergy: Float = 0
        for frame in 0..<compareFrames {
            for ch in 0..<channelCount {
                let tailIdx = (tailFrames - compareFrames + frame) * channelCount + ch
                let dataIdx = frame * channelCount + ch
                if tailIdx < previousTail.count {
                    let a = previousTail[tailIdx]
                    let b = data[dataIdx]
                    totalDiff += abs(a - b)
                    totalEnergy += abs(a) + abs(b)
                }
            }
        }
        
        // 只有当差异极小（< 1%）才认为是真正的重叠
        let normalizedDiff = totalEnergy > 0.001 ? totalDiff / totalEnergy : 1.0
        if normalizedDiff < 0.01 && totalEnergy > 0.01 {
            let fadeFrames = min(16, frameCount)
            for frame in 0..<fadeFrames {
                let fadeIn = Float(frame) / Float(fadeFrames)
                for ch in 0..<channelCount {
                    let idx = frame * channelCount + ch
                    data[idx] *= fadeIn
                }
            }
            stats.overlapsFixed += 1
        }
    }

    // MARK: - 6. 削波修复

    private func applyDeclip(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int
    ) {
        for ch in 0..<channelCount {
            var clipStart = -1
            for frame in 0..<frameCount {
                let idx = frame * channelCount + ch
                let sample = data[idx]
                let isClipped = abs(sample) >= clipThreshold
                if isClipped && clipStart < 0 {
                    clipStart = frame
                } else if !isClipped && clipStart >= 0 {
                    repairClippedRegion(data, ch: ch, channelCount: channelCount,
                        start: clipStart, end: frame, totalFrames: frameCount)
                    clipStart = -1
                }
            }
            if clipStart >= 0 {
                repairClippedRegion(data, ch: ch, channelCount: channelCount,
                    start: clipStart, end: frameCount, totalFrames: frameCount)
            }
        }
    }

    private func repairClippedRegion(
        _ data: UnsafeMutablePointer<Float>,
        ch: Int, channelCount: Int,
        start: Int, end: Int, totalFrames: Int
    ) {
        let clipLength = end - start
        guard clipLength > 0 && clipLength < 512 else { return }
        stats.clippedSamplesRepaired += clipLength
        let preIdx = max(0, start - 1)
        let postIdx = min(totalFrames - 1, end)
        let preValue = data[preIdx * channelCount + ch]
        let postValue = data[postIdx * channelCount + ch]
        let preSlope: Float = start >= 2
            ? data[preIdx * channelCount + ch] - data[(preIdx - 1) * channelCount + ch] : 0
        let postSlope: Float = end < totalFrames - 1
            ? data[(postIdx + 1) * channelCount + ch] - data[postIdx * channelCount + ch] : 0
        for i in 0..<clipLength {
            let t = Float(i + 1) / Float(clipLength + 1)
            let interpolated = hermiteInterpolate(preValue, postValue, preSlope, postSlope, t)
            let idx = (start + i) * channelCount + ch
            let originalSign: Float = data[idx] >= 0 ? 1.0 : -1.0
            let repaired = abs(interpolated) * originalSign
            data[idx] = max(-0.98, min(0.98, repaired))
        }
    }

    private func hermiteInterpolate(
        _ y0: Float, _ y1: Float, _ m0: Float, _ m1: Float, _ t: Float
    ) -> Float {
        let t2 = t * t
        let t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * y0 + (t3 - 2 * t2 + t) * m0
             + (-2 * t3 + 3 * t2) * y1 + (t3 - t2) * m1
    }

    // MARK: - 7. 超高频噪声滤除

    private func applyUltrasonicFilter(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int, channelCount: Int, sampleRate: Int
    ) {
        guard sampleRate > 44100 else { return }
        let cutoff: Float = 20000.0
        let rc = 1.0 / (2.0 * Float.pi * cutoff)
        let dt = 1.0 / Float(sampleRate)
        let alpha = dt / (rc + dt)
        for ch in 0..<channelCount {
            var prev = dcFilterState[ch].xPrev
            for frame in 0..<frameCount {
                let idx = frame * channelCount + ch
                let filtered = prev + alpha * (data[idx] - prev)
                data[idx] = filtered
                prev = filtered
            }
        }
    }

    // MARK: - 8. 软限幅

    private func applySoftLimiter(
        _ data: UnsafeMutablePointer<Float>, totalSamples: Int
    ) {
        let threshold = limiterThreshold
        let invThreshold = 1.0 / threshold
        var activated = false
        for i in 0..<totalSamples {
            let sample = data[i]
            let absSample = abs(sample)
            if absSample > threshold {
                let sign: Float = sample >= 0 ? 1.0 : -1.0
                let excess = (absSample - threshold) * invThreshold
                let compressed = threshold + (1.0 - threshold) * tanhf(excess)
                data[i] = sign * compressed
                activated = true
            }
        }
        if activated { stats.limiterActivations += 1 }
    }

    // MARK: - 9. 抖动

    private func applyDither(
        _ data: UnsafeMutablePointer<Float>, totalSamples: Int
    ) {
        let ditherAmplitude: Float = 2.0 / 32768.0
        for i in 0..<totalSamples {
            ditherState = ditherState * 1664525 + 1013904223
            let r1 = ditherState / Float(UInt32.max) - 0.5
            ditherState = ditherState * 1664525 + 1013904223
            let r2 = ditherState / Float(UInt32.max) - 0.5
            data[i] += (r1 + r2) * ditherAmplitude
        }
    }

    // MARK: - 10. 滤镜重建过渡

    private func applyFilterTransition(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int, channelCount: Int
    ) {
        let totalSamples = frameCount * channelCount

        // 正在进行过渡交叉淡化
        if transitionRemaining > 0 && !transitionBuffer.isEmpty {
            let samplesToFade = min(transitionRemaining, frameCount)
            let bufferFrames = transitionBuffer.count / max(channelCount, 1)
            for frame in 0..<samplesToFade {
                let t = Float(transitionLength - transitionRemaining + frame) / Float(transitionLength)
                let newWeight = t * t * (3.0 - 2.0 * t)
                let oldWeight = 1.0 - newWeight
                for ch in 0..<channelCount {
                    let idx = frame * channelCount + ch
                    let bufFrame = bufferFrames - transitionRemaining + frame
                    if bufFrame >= 0 && bufFrame < bufferFrames {
                        let bufIdx = bufFrame * channelCount + ch
                        if bufIdx < transitionBuffer.count {
                            data[idx] = data[idx] * newWeight + transitionBuffer[bufIdx] * oldWeight
                        }
                    }
                }
            }
            transitionRemaining -= samplesToFade
            if transitionRemaining <= 0 { transitionBuffer.removeAll() }
            return
        }

        // 计算当前帧 RMS
        var sumSq: Float = 0
        let checkSamples = min(64 * channelCount, totalSamples)
        for i in 0..<checkSamples { sumSq += data[i] * data[i] }
        let currentRMS = sqrtf(sumSq / Float(max(checkSamples, 1)))

        // 检测 RMS 突变 - 只有非常剧烈的变化才触发（>12dB = 4倍）
        // 并且需要连续稳定至少 10 帧后才检测，避免正常音乐动态被误判
        if prevFrameRMS > 0.01 && currentRMS > 0.01 && stableFrameCount > 10 {
            let rmsRatio = currentRMS / prevFrameRMS
            // 只有 RMS 变化超过 4 倍（12dB）才认为是滤镜重建
            if rmsRatio > 4.0 || rmsRatio < 0.25 {
                if !previousTail.isEmpty && previousTail.count >= channelCount {
                    var maxJump: Float = 0
                    let tailFrames = previousTail.count / channelCount
                    for ch in 0..<channelCount {
                        let lastTailIdx = (tailFrames - 1) * channelCount + ch
                        if lastTailIdx < previousTail.count {
                            maxJump = max(maxJump, abs(data[ch] - previousTail[lastTailIdx]))
                        }
                    }
                    // 波形跳变阈值也提高到 0.3
                    if maxJump > 0.3 {
                        let jumpFactor = min(maxJump / 0.5, 1.0)
                        let fadeSamples = Int(Float(filterTransitionMaxSamples) * (0.3 + 0.7 * jumpFactor))
                        let actualFade = min(fadeSamples, frameCount)
                        let tailFrameCount = previousTail.count / channelCount
                        transitionBuffer = Array(repeating: Float(0), count: actualFade * channelCount)
                        for frame in 0..<actualFade {
                            for ch in 0..<channelCount {
                                let srcFrame = tailFrameCount - actualFade + frame
                                if srcFrame >= 0 {
                                    let srcIdx = srcFrame * channelCount + ch
                                    if srcIdx < previousTail.count {
                                        transitionBuffer[frame * channelCount + ch] = previousTail[srcIdx]
                                    }
                                }
                            }
                        }
                        transitionLength = actualFade
                        transitionRemaining = actualFade
                        stableFrameCount = 0
                        stats.filterTransitions += 1

                        let samplesToFade = min(transitionRemaining, frameCount)
                        for frame in 0..<samplesToFade {
                            let t = Float(frame) / Float(transitionLength)
                            let newWeight = t * t * (3.0 - 2.0 * t)
                            let oldWeight = 1.0 - newWeight
                            for ch in 0..<channelCount {
                                let idx = frame * channelCount + ch
                                let bufIdx = frame * channelCount + ch
                                if bufIdx < transitionBuffer.count {
                                    data[idx] = data[idx] * newWeight + transitionBuffer[bufIdx] * oldWeight
                                }
                            }
                        }
                        transitionRemaining -= samplesToFade
                        if transitionRemaining <= 0 { transitionBuffer.removeAll() }
                    }
                }
            }
        }
        prevFrameRMS = currentRMS
        stableFrameCount += 1
    }

    // MARK: - 11. 响度突变抑制

    private func applyLoudnessStabilizer(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int, channelCount: Int
    ) {
        let totalSamples = frameCount * channelCount
        var sumSq: Float = 0
        for i in 0..<totalSamples { sumSq += data[i] * data[i] }
        let currentRMS = sqrtf(sumSq / Float(max(totalSamples, 1)))

        if rmsEnvelope < 0.0001 {
            rmsEnvelope = currentRMS
        } else {
            rmsEnvelope = rmsEnvelope * (1.0 - loudnessSmoothing) + currentRMS * loudnessSmoothing
        }

        if loudnessSmoothRemaining > 0 {
            let totalSmoothFrames = 2048
            let progress = Float(totalSmoothFrames - loudnessSmoothRemaining) / Float(totalSmoothFrames)
            let t = progress * progress * (3.0 - 2.0 * progress)
            let currentGain = loudnessSmoothStartGain + (1.0 - loudnessSmoothStartGain) * t
            for i in 0..<totalSamples { data[i] *= currentGain }
            loudnessSmoothRemaining -= frameCount
            if loudnessSmoothRemaining <= 0 {
                loudnessGain = 1.0
                loudnessSmoothRemaining = 0
            }
        } else if previousRMS > 0.001 && currentRMS > 0.001 {
            let rmsDB = 20.0 * log10f(currentRMS / previousRMS)
            if abs(rmsDB) > loudnessJumpThreshold {
                let compensationGain = previousRMS / currentRMS
                let clampedGain = max(0.25, min(4.0, compensationGain))
                for i in 0..<totalSamples { data[i] *= clampedGain }
                loudnessSmoothStartGain = clampedGain
                loudnessSmoothRemaining = 2048
                loudnessGain = clampedGain
                stats.loudnessJumpsSmoothed += 1
            }
        }
        previousRMS = currentRMS
    }

    // MARK: - 12. 混响尾音保护

    private func applyReverbTailGuard(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int, channelCount: Int
    ) {
        if reverbTailActive && reverbTailRemaining > 0 && !reverbHistory.isEmpty {
            let historyFrames = reverbHistory.count / max(reverbHistoryChannels, 1)
            guard reverbHistoryChannels == channelCount else {
                reverbTailActive = false
                return
            }
            let framesToFill = min(reverbTailRemaining, frameCount)
            let tailTotalFrames = min(2048, historyFrames)
            for frame in 0..<framesToFill {
                let progress = Float(tailTotalFrames - reverbTailRemaining + frame) / Float(tailTotalFrames)
                let decay = expf(-3.0 * progress)
                for ch in 0..<channelCount {
                    let histFrame = (reverbHistoryWritePos - reverbTailRemaining + frame + historyFrames) % historyFrames
                    let histIdx = histFrame * channelCount + ch
                    if histIdx >= 0 && histIdx < reverbHistory.count {
                        let dataIdx = frame * channelCount + ch
                        data[dataIdx] += reverbHistory[histIdx] * decay * 0.5
                    }
                }
            }
            reverbTailRemaining -= framesToFill
            if reverbTailRemaining <= 0 { reverbTailActive = false }
            stats.reverbTailsFilled += 1
            return
        }

        guard !reverbHistory.isEmpty && reverbHistoryChannels == channelCount else { return }
        let totalSamples = frameCount * channelCount
        let historyFrames = reverbHistory.count / channelCount

        let checkSamples = min(32 * channelCount, totalSamples)
        var currentEnergy: Float = 0
        for i in 0..<checkSamples { currentEnergy += data[i] * data[i] }
        currentEnergy = sqrtf(currentEnergy / Float(max(checkSamples, 1)))

        let histCheckFrames = min(32, historyFrames)
        var histEnergy: Float = 0
        for frame in 0..<histCheckFrames {
            let histFrame = (reverbHistoryWritePos - histCheckFrames + frame + historyFrames) % historyFrames
            for ch in 0..<channelCount {
                let idx = histFrame * channelCount + ch
                if idx < reverbHistory.count { histEnergy += reverbHistory[idx] * reverbHistory[idx] }
            }
        }
        histEnergy = sqrtf(histEnergy / Float(max(histCheckFrames * channelCount, 1)))

        // 只有当能量突然下降到 5% 以下才认为是混响断裂
        // 0.3 (30%) 太敏感，正常音乐动态会误触发
        if histEnergy > 0.05 && currentEnergy < histEnergy * 0.05 {
            reverbTailActive = true
            reverbTailRemaining = min(2048, historyFrames)
        }
    }

    private func updateReverbHistory(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int, channelCount: Int
    ) {
        let targetSize = reverbTailHistoryLength * channelCount
        if reverbHistory.count != targetSize || reverbHistoryChannels != channelCount {
            reverbHistory = Array(repeating: 0, count: targetSize)
            reverbHistoryWritePos = 0
            reverbHistoryChannels = channelCount
        }
        let historyFrames = reverbTailHistoryLength
        for frame in 0..<frameCount {
            let writeFrame = (reverbHistoryWritePos + frame) % historyFrames
            for ch in 0..<channelCount {
                let srcIdx = frame * channelCount + ch
                let dstIdx = writeFrame * channelCount + ch
                if dstIdx < reverbHistory.count { reverbHistory[dstIdx] = data[srcIdx] }
            }
        }
        reverbHistoryWritePos = (reverbHistoryWritePos + frameCount) % historyFrames
    }

    // MARK: - 13. 相位连续性修复

    private func applyPhaseContinuity(
        _ data: UnsafeMutablePointer<Float>,
        frameCount: Int, channelCount: Int
    ) {
        guard frameCount >= 4 else { return }

        var currentDirection = [Float](repeating: 0, count: channelCount)
        for ch in 0..<channelCount {
            var slope: Float = 0
            for frame in 1..<min(4, frameCount) {
                slope += data[frame * channelCount + ch] - data[(frame - 1) * channelCount + ch]
            }
            currentDirection[ch] = slope
        }

        if !previousPhaseDirection.isEmpty && previousPhaseDirection.count == channelCount {
            var flippedChannels = 0
            var totalChecked = 0
            for ch in 0..<channelCount {
                let prev = previousPhaseDirection[ch]
                let curr = currentDirection[ch]
                // 提高斜率阈值到 0.1，避免低能量信号的噪声干扰
                if abs(prev) > 0.1 && abs(curr) > 0.1 {
                    totalChecked += 1
                    if prev * curr < 0 { flippedChannels += 1 }
                }
            }

            if totalChecked > 0 && flippedChannels == totalChecked {
                if !previousTail.isEmpty && previousTail.count >= channelCount {
                    let tailFrames = previousTail.count / channelCount
                    var amplitudeMatch = true
                    for ch in 0..<channelCount {
                        let lastTailIdx = (tailFrames - 1) * channelCount + ch
                        if lastTailIdx < previousTail.count {
                            let prevAmp = abs(previousTail[lastTailIdx])
                            let currAmp = abs(data[ch])
                            if prevAmp > 0.01 && abs(currAmp - prevAmp) / prevAmp > 0.5 {
                                amplitudeMatch = false
                                break
                            }
                        }
                    }
                    if amplitudeMatch {
                        let fadeFrames = min(64, frameCount)
                        let tailFrameCount = previousTail.count / channelCount
                        for frame in 0..<fadeFrames {
                            let t = Float(frame) / Float(fadeFrames)
                            let newWeight = t * t * (3.0 - 2.0 * t)
                            let oldWeight = 1.0 - newWeight
                            for ch in 0..<channelCount {
                                let idx = frame * channelCount + ch
                                let lastIdx = (tailFrameCount - 1) * channelCount + ch
                                if lastIdx < previousTail.count {
                                    data[idx] = data[idx] * newWeight + previousTail[lastIdx] * oldWeight
                                }
                            }
                        }
                        stats.phaseFlipsFixed += 1
                    }
                }
            }
        }
        previousPhaseDirection = currentDirection
    }
}
