// FFmpegAudioFilterDiagnostics.swift
// FFmpegSwiftSDK

import Foundation

/// One independently executable audio-effect path used by Mono's FFmpeg graph.
public struct FFmpegAudioFilterTestCase: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let filterNames: [String]
    public let isInMonoPlaybackPath: Bool

    public init(
        id: String,
        title: String,
        filterNames: [String],
        isInMonoPlaybackPath: Bool = false
    ) {
        self.id = id
        self.title = title
        self.filterNames = filterNames
        self.isInMonoPlaybackPath = isInMonoPlaybackPath
    }
}

public struct FFmpegAudioFilterTestResult: Sendable {
    public let processedFrames: Int
    public let inputPeak: Float
    public let outputPeak: Float
    public let levelDeltaDB: Float
    public let changedSampleRatio: Float
    public let clippedSampleCount: Int
    public let emptyOutputBlockCount: Int
    public let outputFrameRatio: Float
    public let realtimeLoad: Float
    public let graphBuildMilliseconds: Double
    public let discontinuityRatio: Float
}

/// Builds and runs each production audio-filter path against caller supplied
/// PCM. Diagnostics are isolated from the live StreamPlayer graph.
public enum FFmpegAudioFilterDiagnostics {
    public static let testCases: [FFmpegAudioFilterTestCase] = [
        .init(id: "volume", title: "音量增益", filterNames: ["volume"]),
        .init(id: "loudnorm", title: "响度标准化", filterNames: ["loudnorm"]),
        .init(id: "compressor", title: "动态压缩", filterNames: ["acompressor"]),
        .init(id: "limiter", title: "峰值限幅", filterNames: ["alimiter"]),
        .init(id: "gate", title: "噪声门", filterNames: ["agate"]),
        .init(id: "auto-gain", title: "自动增益", filterNames: ["dynaudnorm"]),
        .init(id: "tempo", title: "速度调整", filterNames: ["atempo"], isInMonoPlaybackPath: true),
        .init(id: "pitch", title: "音调调整", filterNames: ["asetrate", "aresample", "atempo"], isInMonoPlaybackPath: true),
        .init(id: "bass", title: "低音调节", filterNames: ["bass"]),
        .init(id: "treble", title: "高音调节", filterNames: ["treble"]),
        .init(id: "subboost", title: "超低音增强", filterNames: ["asubboost"]),
        .init(id: "bandpass", title: "带通滤波", filterNames: ["bandpass"]),
        .init(id: "bandreject", title: "带阻滤波", filterNames: ["bandreject"]),
        .init(id: "surround", title: "环绕声场", filterNames: ["stereotools"], isInMonoPlaybackPath: true),
        .init(id: "reverb", title: "空间混响", filterNames: ["aecho"], isInMonoPlaybackPath: true),
        .init(id: "stereo-width", title: "立体声宽度", filterNames: ["stereotools"]),
        .init(id: "balance", title: "左右平衡", filterNames: ["pan"]),
        .init(id: "mono", title: "单声道下混", filterNames: ["pan"]),
        .init(id: "channel-swap", title: "声道交换", filterNames: ["pan"]),
        .init(id: "fade-in", title: "淡入", filterNames: ["afade"]),
        .init(id: "fade-out", title: "淡出", filterNames: ["afade"]),
        .init(id: "delay", title: "声道延迟", filterNames: ["adelay"]),
        .init(id: "vocal-removal", title: "中置人声削弱", filterNames: ["stereotools"]),
        .init(id: "chorus", title: "合唱", filterNames: ["chorus"]),
        .init(id: "flanger", title: "镶边", filterNames: ["flanger"]),
        .init(id: "tremolo", title: "音量颤音", filterNames: ["tremolo"]),
        .init(id: "vibrato", title: "音调颤音", filterNames: ["vibrato"]),
        .init(id: "crusher", title: "位深压碎", filterNames: ["acrusher"]),
        .init(id: "telephone", title: "电话频响", filterNames: ["bandpass"]),
        .init(id: "underwater", title: "水下空间", filterNames: ["lowpass", "aecho"]),
        .init(id: "radio", title: "收音机质感", filterNames: ["bandpass", "acrusher"]),
        .init(id: "fft-denoise", title: "FFT 降噪", filterNames: ["afftdn"]),
        .init(id: "declick", title: "脉冲噪声修复", filterNames: ["adeclick"]),
        .init(id: "declip", title: "削波修复", filterNames: ["adeclip"]),
        .init(id: "dynamic-normalize", title: "动态标准化", filterNames: ["dynaudnorm"]),
        .init(id: "speech-normalize", title: "人声标准化", filterNames: ["speechnorm"]),
        .init(id: "compand", title: "动态扩展压缩", filterNames: ["compand"]),
        .init(id: "bs2b", title: "双耳交叉馈送", filterNames: ["bs2b"]),
        .init(id: "crossfeed", title: "耳机交叉馈送", filterNames: ["stereotools"]),
        .init(id: "haas", title: "Haas 声场", filterNames: ["haas"]),
        .init(id: "virtual-bass", title: "虚拟低音", filterNames: ["virtualbass"]),
        .init(id: "exciter", title: "谐波激励", filterNames: ["aexciter"]),
        .init(id: "softclip", title: "软削波", filterNames: ["asoftclip"]),
        .init(id: "dialogue", title: "人声清晰增强", filterNames: ["dialoguenhance"]),
        .init(id: "mono-standard-chain", title: "标准调音 FFmpeg 组合链", filterNames: ["stereotools", "aecho"], isInMonoPlaybackPath: true),
        .init(id: "mono-spatial-chain", title: "空间增强 FFmpeg 组合链", filterNames: ["stereotools", "aecho"], isInMonoPlaybackPath: true)
    ]

    public static func run(
        id: String,
        samples: [Float],
        sampleRate: Int,
        channelCount: Int
    ) throws -> FFmpegAudioFilterTestResult {
        guard testCases.contains(where: { $0.id == id }) else {
            throw FFmpegError.unsupportedFormat(codecName: "未知滤镜测试：\(id)")
        }
        guard sampleRate > 0, channelCount == 2, samples.count >= channelCount * 2_048 else {
            throw FFmpegError.unsupportedFormat(codecName: "需要双声道 PCM")
        }

        let graph = AudioFilterGraph()
        configure(graph, id: id)

        let framesPerBlock = 2_048
        let samplesPerBlock = framesPerBlock * channelCount
        let source = Array(samples.prefix(max(samplesPerBlock, min(samples.count, samplesPerBlock * 24))))
        var block = [Float](repeating: 0, count: samplesPerBlock)
        var sourceOffset = 0
        var processedFrames = 0
        var fedFrames = 0
        var inputPeak: Float = 0
        var outputPeak: Float = 0
        var inputEnergy: Double = 0
        var outputEnergy: Double = 0
        var inputSampleCount = 0
        var outputSampleCount = 0
        var comparedSampleCount = 0
        var changedSampleCount = 0
        var clippedSampleCount = 0
        var emptyOutputBlockCount = 0
        var maximumInputStep: Float = 0
        var maximumOutputStep: Float = 0
        var previousInputSamples = [Float?](repeating: nil, count: channelCount)
        var previousOutputSamples = [Float?](repeating: nil, count: channelCount)
        var processingSeconds: Double = 0
        var graphReadyAt: TimeInterval?
        let startedAt = ProcessInfo.processInfo.systemUptime
        let requiredMeasuredBlocks = 16
        var measuredBlocks = 0

        for _ in 0..<180 {
            if sourceOffset + samplesPerBlock > source.count { sourceOffset = 0 }
            block.replaceSubrange(0..<samplesPerBlock, with: source[sourceOffset..<(sourceOffset + samplesPerBlock)])
            sourceOffset += samplesPerBlock
            let inputSamples = block

            let processStartedAt = ProcessInfo.processInfo.systemUptime
            let output = block.withUnsafeMutableBufferPointer { pointer in
                graph.process(
                    AudioBuffer(
                        data: pointer.baseAddress!,
                        frameCount: framesPerBlock,
                        channelCount: channelCount,
                        sampleRate: sampleRate
                    )
                )
            }
            let blockProcessingSeconds = ProcessInfo.processInfo.systemUptime - processStartedAt

            if graph.isReadyForDiagnostics(sampleRate: sampleRate, channelCount: channelCount) {
                processingSeconds += blockProcessingSeconds
                if graphReadyAt == nil {
                    graphReadyAt = ProcessInfo.processInfo.systemUptime
                }
                let count = output.frameCount * output.channelCount
                fedFrames += framesPerBlock
                guard count > 0 else {
                    emptyOutputBlockCount += 1
                    continue
                }
                let outputSamples = UnsafeBufferPointer(start: output.data, count: count)
                guard outputSamples.allSatisfy(\.isFinite) else {
                    throw FFmpegError.unsupportedFormat(codecName: "滤镜输出包含无效采样")
                }

                for index in inputSamples.indices {
                    let value = inputSamples[index]
                    let channel = index % channelCount
                    inputPeak = max(inputPeak, abs(value))
                    inputEnergy += Double(value * value)
                    if let previous = previousInputSamples[channel] {
                        maximumInputStep = max(maximumInputStep, abs(value - previous))
                    }
                    previousInputSamples[channel] = value
                }
                inputSampleCount += inputSamples.count

                for index in 0..<count {
                    let value = outputSamples[index]
                    let channel = index % max(1, output.channelCount)
                    outputPeak = max(outputPeak, abs(value))
                    outputEnergy += Double(value * value)
                    if abs(value) > 1 { clippedSampleCount += 1 }
                    if channel < previousOutputSamples.count {
                        if let previous = previousOutputSamples[channel] {
                            maximumOutputStep = max(maximumOutputStep, abs(value - previous))
                        }
                        previousOutputSamples[channel] = value
                    }
                }
                outputSampleCount += count

                let comparableCount = min(inputSamples.count, count)
                for index in 0..<comparableCount {
                    let input = inputSamples[index]
                    let value = outputSamples[index]
                    if abs(value - input) > 0.000_1 { changedSampleCount += 1 }
                }
                comparedSampleCount += comparableCount
                processedFrames += output.frameCount
                measuredBlocks += 1
                if measuredBlocks >= requiredMeasuredBlocks {
                    let inputRMS = sqrt(inputEnergy / Double(max(1, inputSampleCount)))
                    let outputRMS = sqrt(outputEnergy / Double(max(1, outputSampleCount)))
                    let levelDeltaDB = 20 * log10(max(outputRMS, 0.000_000_1) / max(inputRMS, 0.000_000_1))
                    let audioSeconds = Double(fedFrames) / Double(sampleRate)
                    let frameRatio = Float(processedFrames) / Float(max(1, fedFrames))
                    return FFmpegAudioFilterTestResult(
                        processedFrames: processedFrames,
                        inputPeak: inputPeak,
                        outputPeak: outputPeak,
                        levelDeltaDB: Float(levelDeltaDB),
                        changedSampleRatio: Float(changedSampleCount) / Float(max(1, comparedSampleCount)),
                        clippedSampleCount: clippedSampleCount,
                        emptyOutputBlockCount: emptyOutputBlockCount,
                        outputFrameRatio: frameRatio,
                        realtimeLoad: Float(processingSeconds / max(audioSeconds, 0.000_1)),
                        graphBuildMilliseconds: ((graphReadyAt ?? ProcessInfo.processInfo.systemUptime) - startedAt) * 1_000,
                        discontinuityRatio: maximumOutputStep / max(maximumInputStep, 0.000_1)
                    )
                }
            } else {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }

        throw FFmpegError.unsupportedFormat(codecName: "滤镜图建立失败")
    }

    private static func configure(_ graph: AudioFilterGraph, id: String) {
        switch id {
        case "volume": graph.setVolume(3)
        case "loudnorm": graph.setLoudnormParams(); graph.setLoudnormEnabled(true)
        case "compressor": graph.setCompressorParams(); graph.setCompressorEnabled(true)
        case "limiter": graph.setLimiterLimit(-1); graph.setLimiterEnabled(true)
        case "gate": graph.setGateThreshold(-42); graph.setGateEnabled(true)
        case "auto-gain": graph.setAutoGainEnabled(true)
        case "tempo": graph.setTempo(1.08)
        case "pitch": graph.setPitchSemitones(2)
        case "bass": graph.setBassGain(3)
        case "treble": graph.setTrebleGain(3)
        case "subboost": graph.setSubboostParams(); graph.setSubboostEnabled(true)
        case "bandpass": graph.setBandpassParams(frequency: 1_000, width: 1_800); graph.setBandpassEnabled(true)
        case "bandreject": graph.setBandrejectParams(frequency: 1_000, width: 220); graph.setBandrejectEnabled(true)
        case "surround": graph.setSurroundLevel(0.55)
        case "reverb": graph.setReverbLevel(0.32)
        case "stereo-width": graph.setStereoWidth(1.35)
        case "balance": graph.setChannelBalance(0.2)
        case "mono": graph.setMonoEnabled(true)
        case "channel-swap": graph.setChannelSwapEnabled(true)
        case "fade-in": graph.setFadeIn(duration: 0.15)
        case "fade-out": graph.setFadeOut(duration: 0.15, startTime: 0.02)
        case "delay": graph.setDelay(35)
        case "vocal-removal": graph.setVocalRemoval(0.45)
        case "chorus": graph.setChorusDepth(0.4); graph.setChorusEnabled(true)
        case "flanger": graph.setFlangerDepth(0.35); graph.setFlangerEnabled(true)
        case "tremolo": graph.setTremoloParams(); graph.setTremoloEnabled(true)
        case "vibrato": graph.setVibratoParams(); graph.setVibratoEnabled(true)
        case "crusher": graph.setCrusherParams(bits: 10, samples: 2); graph.setCrusherEnabled(true)
        case "telephone": graph.setTelephoneEnabled(true)
        case "underwater": graph.setUnderwaterEnabled(true)
        case "radio": graph.setRadioEnabled(true)
        case "fft-denoise": graph.setFFTDenoiseAmount(8); graph.setFFTDenoiseEnabled(true)
        case "declick": graph.setDeclickEnabled(true)
        case "declip": graph.setDeclipEnabled(true)
        case "dynamic-normalize": graph.setDynaudnormParams(); graph.setDynaudnormEnabled(true)
        case "speech-normalize": graph.setSpeechnormEnabled(true)
        case "compand": graph.setCompandEnabled(true)
        case "bs2b": graph.setBS2BParams(); graph.setBS2BEnabled(true)
        case "crossfeed": graph.setCrossfeedStrength(0.35); graph.setCrossfeedEnabled(true)
        case "haas": graph.setHaasDelay(18); graph.setHaasEnabled(true)
        case "virtual-bass": graph.setVirtualbassParams(); graph.setVirtualbassEnabled(true)
        case "exciter": graph.setExciterParams(); graph.setExciterEnabled(true)
        case "softclip": graph.setSoftclipType(0); graph.setSoftclipEnabled(true)
        case "dialogue": graph.setDialogueEnhanceParams(original: 1, enhance: 1.4); graph.setDialogueEnhanceEnabled(true)
        case "mono-standard-chain":
            graph.setSurroundLevel(0.1)
            graph.setReverbLevel(0.06)
        case "mono-spatial-chain":
            graph.setSurroundLevel(0.38)
            graph.setReverbLevel(0.34)
        default: break
        }
    }
}
