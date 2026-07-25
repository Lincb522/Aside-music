// MonoAudioPipelineDiagnostics.swift
// FFmpegSwiftSDK

import Foundation

/// One independently executable stage from Mono's realtime PCM pipeline.
public struct MonoAudioPipelineTestCase: Identifiable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// Exercises the native EQ and final-output repair stages without touching the
/// graph owned by the live player.
public enum MonoAudioPipelineDiagnostics {
    public static let testCases: [MonoAudioPipelineTestCase] = [
        .init(id: "graphic-eq-10", title: "10 段均衡器"),
        .init(id: "graphic-eq-32", title: "32 段均衡器"),
        .init(id: "calibration-eq", title: "输出设备校准"),
        .init(id: "adaptive-eq", title: "歌曲自适应补偿"),
        .init(id: "parametric-eq", title: "参数均衡器"),
        .init(id: "dynamic-eq", title: "动态均衡器"),
        .init(id: "multiband", title: "三段动态处理"),
        .init(id: "mono-enhance", title: "Mono 智能校准"),
        .init(id: "preamp", title: "前级增益"),
        .init(id: "native-standard-chain", title: "标准调音原生组合链"),
        .init(id: "native-spatial-chain", title: "空间增强原生组合链"),
        .init(id: "repair-limiter", title: "输出限幅"),
        .init(id: "repair-declip", title: "削波修复"),
        .init(id: "repair-denoise", title: "超声与直流清理"),
        .init(id: "repair-gap", title: "断点平滑"),
        .init(id: "repair-overlap", title: "重叠修复"),
        .init(id: "repair-pop", title: "爆音抑制"),
        .init(id: "repair-dither", title: "输出抖动"),
        .init(id: "repair-fade", title: "启动淡入保护"),
        .init(id: "repair-loudness", title: "响度突变保护"),
        .init(id: "repair-reverb-tail", title: "混响尾音保护"),
        .init(id: "repair-phase", title: "相位连续保护"),
        .init(id: "repair-transition", title: "滤镜切换保护"),
        .init(id: "repair-dc", title: "直流偏移保护"),
        .init(id: "repair-output-makeup", title: "输出响度补偿")
    ]

    public static func run(
        id: String,
        samples: [Float],
        sampleRate: Int,
        channelCount: Int
    ) throws -> FFmpegAudioFilterTestResult {
        guard testCases.contains(where: { $0.id == id }) else {
            throw FFmpegError.unsupportedFormat(codecName: "未知实时处理测试：\(id)")
        }
        guard sampleRate > 0, channelCount > 0, samples.count >= channelCount * 2_048 else {
            throw FFmpegError.unsupportedFormat(codecName: "当前歌曲 PCM 不足")
        }

        if id.hasPrefix("repair-") {
            let repair = AudioRepairEngine()
            configure(repair, id: id)
            return measure(
                samples: samples,
                sampleRate: sampleRate,
                channelCount: channelCount
            ) { data, frames, channels, rate in
                repair.process(
                    data,
                    frameCount: frames,
                    channelCount: channels,
                    sampleRate: rate
                )
            }
        }

        let equalizer = EQFilter()
        configure(equalizer, id: id)
        return measure(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: channelCount
        ) { data, frames, channels, rate in
            _ = equalizer.process(
                AudioBuffer(
                    data: data,
                    frameCount: frames,
                    channelCount: channels,
                    sampleRate: rate
                )
            )
        }
    }

    private static func configure(_ equalizer: EQFilter, id: String) {
        switch id {
        case "graphic-eq-10":
            equalizer.setGraphicMode(
                .tenBand,
                gains: GraphicEQMode.tenBand.centerFrequencies.indices.map {
                    $0.isMultiple(of: 2) ? 2.5 : -1.5
                }
            )
        case "graphic-eq-32":
            equalizer.setGraphicMode(
                .thirtyTwoBand,
                gains: GraphicEQMode.thirtyTwoBand.centerFrequencies.indices.map {
                    $0.isMultiple(of: 3) ? 2.0 : -0.8
                }
            )
        case "calibration-eq":
            equalizer.setCalibrationGains(
                GraphicEQMode.tenBand.centerFrequencies.indices.map {
                    $0.isMultiple(of: 2) ? 1.5 : -1
                }
            )
        case "adaptive-eq":
            equalizer.setAdaptiveGains(
                GraphicEQMode.tenBand.centerFrequencies.indices.map {
                    $0.isMultiple(of: 3) ? 1.2 : -0.6
                }
            )
        case "parametric-eq":
            equalizer.setParametricBands([
                ParametricEQBand(type: .lowShelf, frequency: 90, gainDB: 2, q: 0.8),
                ParametricEQBand(type: .peak, frequency: 2_600, gainDB: 2.5, q: 1.2),
                ParametricEQBand(type: .highShelf, frequency: 9_000, gainDB: 1.5, q: 0.8)
            ])
        case "dynamic-eq":
            equalizer.setDynamicEQ(enabled: true, bands: DynamicEQBand.monoDefaults)
        case "multiband":
            equalizer.setMultibandDynamics(
                MultibandDynamicsConfiguration(isEnabled: true)
            )
        case "mono-enhance":
            equalizer.setMonoEnhance(
                MonoEnhanceConfiguration(
                    isEnabled: true,
                    transientAttack: 0.45,
                    transientSustain: 0.3,
                    vocalFocus: 0.45,
                    airAmount: 0.3,
                    deEssAmount: 0.25,
                    lowFrequencyFocus: 0.35,
                    stageWidth: 0.4,
                    microDynamics: 0.35,
                    lowLevelCompensation: 0.25
                )
            )
        case "preamp":
            equalizer.setPreampDB(-3)
        case "native-standard-chain":
            equalizer.setGraphicMode(
                .thirtyTwoBand,
                gains: GraphicEQMode.thirtyTwoBand.centerFrequencies.indices.map {
                    $0.isMultiple(of: 4) ? 2.2 : -0.7
                }
            )
            equalizer.setParametricBands([
                ParametricEQBand(type: .peak, frequency: 2_400, gainDB: 1.8, q: 1.1)
            ])
            equalizer.setDynamicEQ(enabled: true, bands: DynamicEQBand.monoDefaults)
            equalizer.setMultibandDynamics(MultibandDynamicsConfiguration(isEnabled: true))
            equalizer.setMonoEnhance(
                MonoEnhanceConfiguration(
                    isEnabled: true,
                    transientAttack: 0.45,
                    transientSustain: 0.35,
                    vocalFocus: 0.5,
                    airAmount: 0.35,
                    deEssAmount: 0.3,
                    lowFrequencyFocus: 0.4,
                    stageWidth: 0.12,
                    microDynamics: 0.4,
                    lowLevelCompensation: 0.3
                )
            )
            equalizer.setPreampDB(-3)
        case "native-spatial-chain":
            equalizer.setGraphicMode(
                .thirtyTwoBand,
                gains: GraphicEQMode.thirtyTwoBand.centerFrequencies.indices.map {
                    $0.isMultiple(of: 4) ? 2.2 : -0.7
                }
            )
            equalizer.setParametricBands([
                ParametricEQBand(type: .peak, frequency: 2_400, gainDB: 1.8, q: 1.1)
            ])
            equalizer.setDynamicEQ(enabled: true, bands: DynamicEQBand.monoDefaults)
            equalizer.setMultibandDynamics(MultibandDynamicsConfiguration(isEnabled: true))
            equalizer.setMonoEnhance(
                MonoEnhanceConfiguration(
                    isEnabled: true,
                    transientAttack: 0.45,
                    transientSustain: 0.35,
                    vocalFocus: 0.5,
                    airAmount: 0.35,
                    deEssAmount: 0.3,
                    lowFrequencyFocus: 0.4,
                    stageWidth: 0.66,
                    microDynamics: 0.4,
                    lowLevelCompensation: 0.3
                )
            )
            equalizer.setPreampDB(-3)
        default:
            break
        }
    }

    private static func configure(_ repair: AudioRepairEngine, id: String) {
        switch id {
        case "repair-limiter": repair.isSoftLimiterEnabled = true
        case "repair-declip": repair.isDeclipEnabled = true
        case "repair-denoise": repair.isDenoiseEnabled = true
        case "repair-gap": repair.isGapSmoothingEnabled = true
        case "repair-overlap": repair.isOverlapRemovalEnabled = true
        case "repair-pop": repair.isPopRemovalEnabled = true
        case "repair-dither": repair.isDitherEnabled = true
        case "repair-fade": repair.isFadeInProtectionEnabled = true
        case "repair-loudness": repair.isLoudnessStabilizerEnabled = true
        case "repair-reverb-tail": repair.isReverbTailGuardEnabled = true
        case "repair-phase": repair.isPhaseContinuityEnabled = true
        case "repair-transition": repair.isFilterTransitionEnabled = true
        case "repair-dc": repair.isDCBlockerEnabled = true
        case "repair-output-makeup":
            repair.configureOutputSafety(
                limiterEnabled: true,
                ceilingDB: -1,
                outputGainDB: 2,
                perceptualMakeupDB: 0.8
            )
        default: break
        }
    }

    private static func measure(
        samples: [Float],
        sampleRate: Int,
        channelCount: Int,
        processor: (
            _ data: UnsafeMutablePointer<Float>,
            _ frames: Int,
            _ channels: Int,
            _ sampleRate: Int
        ) -> Void
    ) -> FFmpegAudioFilterTestResult {
        let framesPerBlock = 2_048
        let samplesPerBlock = framesPerBlock * channelCount
        let source = Array(samples.prefix(max(samplesPerBlock, min(samples.count, samplesPerBlock * 24))))
        var block = [Float](repeating: 0, count: samplesPerBlock)
        var offset = 0
        var inputPeak: Float = 0
        var outputPeak: Float = 0
        var inputEnergy: Double = 0
        var outputEnergy: Double = 0
        var changedSamples = 0
        var clippedSamples = 0
        var sampleCount = 0
        var maximumInputStep: Float = 0
        var maximumOutputStep: Float = 0
        var previousInput = [Float?](repeating: nil, count: channelCount)
        var previousOutput = [Float?](repeating: nil, count: channelCount)
        var processingSeconds: Double = 0
        let blockCount = 18

        for _ in 0..<blockCount {
            if offset + samplesPerBlock > source.count { offset = 0 }
            block.replaceSubrange(0..<samplesPerBlock, with: source[offset..<(offset + samplesPerBlock)])
            offset += samplesPerBlock
            let input = block

            let startedAt = ProcessInfo.processInfo.systemUptime
            block.withUnsafeMutableBufferPointer { pointer in
                guard let baseAddress = pointer.baseAddress else { return }
                processor(baseAddress, framesPerBlock, channelCount, sampleRate)
            }
            processingSeconds += ProcessInfo.processInfo.systemUptime - startedAt

            for index in block.indices {
                let channel = index % channelCount
                let dry = input[index]
                let wet = block[index]
                inputPeak = max(inputPeak, abs(dry))
                outputPeak = max(outputPeak, abs(wet))
                inputEnergy += Double(dry * dry)
                outputEnergy += Double(wet * wet)
                if abs(wet - dry) > 0.000_1 { changedSamples += 1 }
                if abs(wet) > 1 { clippedSamples += 1 }
                if let previous = previousInput[channel] {
                    maximumInputStep = max(maximumInputStep, abs(dry - previous))
                }
                if let previous = previousOutput[channel] {
                    maximumOutputStep = max(maximumOutputStep, abs(wet - previous))
                }
                previousInput[channel] = dry
                previousOutput[channel] = wet
            }
            sampleCount += block.count
        }

        let inputRMS = sqrt(inputEnergy / Double(max(1, sampleCount)))
        let outputRMS = sqrt(outputEnergy / Double(max(1, sampleCount)))
        let deltaDB = 20 * log10(max(outputRMS, 0.000_000_1) / max(inputRMS, 0.000_000_1))
        let audioSeconds = Double(blockCount * framesPerBlock) / Double(sampleRate)

        return FFmpegAudioFilterTestResult(
            processedFrames: blockCount * framesPerBlock,
            inputPeak: inputPeak,
            outputPeak: outputPeak,
            levelDeltaDB: Float(deltaDB),
            changedSampleRatio: Float(changedSamples) / Float(max(1, sampleCount)),
            clippedSampleCount: clippedSamples,
            emptyOutputBlockCount: 0,
            outputFrameRatio: 1,
            realtimeLoad: Float(processingSeconds / max(audioSeconds, 0.000_1)),
            graphBuildMilliseconds: 0,
            discontinuityRatio: maximumOutputStep / max(maximumInputStep, 0.000_1)
        )
    }
}
