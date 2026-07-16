import Foundation

enum AIWireProtocol: String, CaseIterable, Codable, Identifiable, Sendable {
    case appleIntelligence
    case openAIResponses
    case openAIChat
    case anthropicMessages
    case googleGemini
    case azureOpenAI
    case ollama
    case openAICompatible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleIntelligence: return String(localized: "ai_protocol_apple")
        case .openAIResponses: return "OpenAI Responses"
        case .openAIChat: return "OpenAI Chat Completions"
        case .anthropicMessages: return "Anthropic Messages"
        case .googleGemini: return "Google Gemini"
        case .azureOpenAI: return "Azure OpenAI"
        case .ollama: return "Ollama"
        case .openAICompatible: return "OpenAI Compatible"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .appleIntelligence: return ""
        case .openAIResponses, .openAIChat: return "https://api.openai.com/v1"
        case .anthropicMessages: return "https://api.anthropic.com/v1"
        case .googleGemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .azureOpenAI: return ""
        case .ollama: return "http://localhost:11434"
        case .openAICompatible: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .appleIntelligence: return String(localized: "ai_model_on_device")
        case .openAIResponses, .openAIChat, .openAICompatible: return "gpt-5-mini"
        case .anthropicMessages: return "claude-sonnet-4-5"
        case .googleGemini: return "gemini-2.5-flash"
        case .azureOpenAI: return ""
        case .ollama: return "qwen3:8b"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .appleIntelligence, .ollama, .openAICompatible: return false
        default: return true
        }
    }

    var supportsCustomEndpoint: Bool { self != .appleIntelligence }
}

struct AIProviderConfiguration: Codable, Equatable, Sendable {
    var wireProtocol: AIWireProtocol
    var baseURL: String
    var model: String
    var modelDiscoveryURL: String
    var timeout: TimeInterval
    var customHeadersJSON: String

    var resolvedBaseURL: String {
        let value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? wireProtocol.defaultBaseURL : value
    }

    var resolvedModel: String {
        let value = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? wireProtocol.defaultModel : value
    }
}

struct AIUsageLimits: Codable, Equatable, Sendable {
    var dailyRequestLimit: Int
    var hourlyRequestLimit: Int
    var minimumRequestInterval: TimeInterval
}

struct AIUsageSnapshot: Equatable, Sendable {
    let usedToday: Int
    let usedThisHour: Int
    let lastRequestAt: Date?
}

struct AIEqualizerAudioFeatures: Codable, Equatable, Sendable {
    let songID: Int
    let title: String
    let artist: String
    let source: String
    let outputDevice: String
    let outputKind: String
    let sampleDuration: Double
    let sampleRate: Double
    let frameCount: Int
    let bandEnergyDB: [Float]
    let spectralCentroidHz: Float
    let spectralRolloffHz: Float
    let rmsDBFS: Float
    let dynamicSpreadDB: Float
    let spectralFlatness: Float
    let currentBassGain: Float
    let currentTrebleGain: Float
    let currentSurroundLevel: Float
    let currentReverbLevel: Float
    let currentStereoWidth: Float
    let professionalProcessingIntensity: Float
    let outputCalibrationEnabled: Bool
    let loudnessMatchingEnabled: Bool
    let smartSongCompensationEnabled: Bool
    let dynamicEQEnabled: Bool
    let multibandDynamicsEnabled: Bool
    let parametricEQEnabled: Bool
}

struct AIEqualizerToneConfiguration: Codable, Equatable, Sendable {
    let bassGain: Float
    let trebleGain: Float
}

struct AIEqualizerSpatialConfiguration: Codable, Equatable, Sendable {
    let surroundLevel: Float
    let reverbLevel: Float
    let stereoWidth: Float
}

struct AIEqualizerCalibrationConfiguration: Codable, Equatable, Sendable {
    let outputCalibrationEnabled: Bool
    let loudnessMatchingEnabled: Bool
    let smartSongCompensationEnabled: Bool
}

struct AIEqualizerDynamicBandConfiguration: Codable, Equatable, Sendable {
    let frequency: Float
    let q: Float
    let thresholdDB: Float
    let ratio: Float
    let maxReductionDB: Float
    let attackMS: Float
    let releaseMS: Float
}

struct AIEqualizerDynamicEQConfiguration: Codable, Equatable, Sendable {
    let enabled: Bool
    let bands: [AIEqualizerDynamicBandConfiguration]
}

struct AIEqualizerMultibandConfiguration: Codable, Equatable, Sendable {
    let enabled: Bool
    let lowCrossoverHz: Float
    let highCrossoverHz: Float
    let thresholdsDB: [Float]
    let ratios: [Float]
    let maxReductionDB: [Float]
    let attackMS: Float
    let releaseMS: Float
}

struct AIEqualizerParametricBandConfiguration: Codable, Equatable, Sendable {
    let type: String
    let frequency: Float
    let gainDB: Float
    let q: Float
}

struct AIEqualizerParametricEQConfiguration: Codable, Equatable, Sendable {
    let enabled: Bool
    let bands: [AIEqualizerParametricBandConfiguration]
}

struct AIEqualizerProfessionalConfiguration: Codable, Equatable, Sendable {
    let processingIntensity: Float
    let dynamicEQ: AIEqualizerDynamicEQConfiguration
    let multiband: AIEqualizerMultibandConfiguration
    let parametricEQ: AIEqualizerParametricEQConfiguration
}

struct AIEqualizerModelOutput: Codable, Equatable, Sendable {
    let profileName: String
    let gains: [Float]
    let preampDB: Float
    let tone: AIEqualizerToneConfiguration?
    let spatial: AIEqualizerSpatialConfiguration?
    let calibration: AIEqualizerCalibrationConfiguration?
    let professional: AIEqualizerProfessionalConfiguration?
    let confidence: Float
    let summary: String
}

struct AIEqualizerProposal: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let songID: Int
    let profileName: String
    let gains: [Float]
    let preampDB: Float
    let tone: AIEqualizerToneConfiguration
    let spatial: AIEqualizerSpatialConfiguration
    let calibration: AIEqualizerCalibrationConfiguration
    let professional: AIEqualizerProfessionalConfiguration
    let confidence: Float
    let summary: String
    let provider: AIWireProtocol
    let model: String
    let createdAt: Date

    init(
        songID: Int,
        output: AIEqualizerModelOutput,
        features: AIEqualizerAudioFeatures,
        provider: AIWireProtocol,
        model: String
    ) {
        let normalized = Self.validatedGains(output.gains)
        let requiredHeadroom = -(normalized.max() ?? 0) - 0.5
        let resolvedSpatial = Self.validatedSpatial(output.spatial, features: features)

        id = UUID()
        self.songID = songID
        profileName = Self.localizedProfileName(
            output.profileName,
            gains: normalized,
            spatial: resolvedSpatial
        )
        gains = normalized
        preampDB = min(0, max(-12, min(output.preampDB, requiredHeadroom)))
        tone = Self.validatedTone(output.tone)
        spatial = resolvedSpatial
        calibration = output.calibration ?? AIEqualizerCalibrationConfiguration(
            outputCalibrationEnabled: true,
            loudnessMatchingEnabled: true,
            smartSongCompensationEnabled: true
        )
        professional = Self.validatedProfessional(output.professional)
        confidence = min(1, max(0, output.confidence))
        summary = Self.localizedSummary(output.summary)
        self.provider = provider
        self.model = model
        createdAt = Date()
    }

    private static func validatedGains(_ values: [Float]) -> [Float] {
        var result = Array(values.prefix(10)).map { value -> Float in
            guard value.isFinite else { return 0 }
            return min(6, max(-6, value))
        }
        if result.count < 10 {
            result.append(contentsOf: repeatElement(Float(0), count: 10 - result.count))
        }
        for index in 1..<result.count {
            result[index] = min(result[index - 1] + 4, max(result[index - 1] - 4, result[index]))
        }
        if result.count > 1 {
            for index in stride(from: result.count - 2, through: 0, by: -1) {
                result[index] = min(result[index + 1] + 4, max(result[index + 1] - 4, result[index]))
            }
        }
        return result
    }

    private static func validatedTone(
        _ value: AIEqualizerToneConfiguration?
    ) -> AIEqualizerToneConfiguration {
        AIEqualizerToneConfiguration(
            bassGain: clampedFinite(value?.bassGain, fallback: 0, range: -6...6),
            trebleGain: clampedFinite(value?.trebleGain, fallback: 0, range: -6...6)
        )
    }

    private static func validatedSpatial(
        _ value: AIEqualizerSpatialConfiguration?,
        features: AIEqualizerAudioFeatures
    ) -> AIEqualizerSpatialConfiguration {
        let proposedSurround = clampedFinite(value?.surroundLevel, fallback: 0, range: 0...0.7)
        let proposedReverb = clampedFinite(value?.reverbLevel, fallback: 0, range: 0...0.45)
        let proposedWidth = clampedFinite(value?.stereoWidth, fallback: 1, range: 0.7...1.6)
        let fallback = spatialFallback(for: features)

        return AIEqualizerSpatialConfiguration(
            surroundLevel: proposedSurround <= 0.005 ? fallback.surroundLevel : proposedSurround,
            reverbLevel: proposedReverb <= 0.005 ? fallback.reverbLevel : proposedReverb,
            stereoWidth: abs(proposedWidth - 1) <= 0.005 ? fallback.stereoWidth : proposedWidth
        )
    }

    private static func spatialFallback(
        for features: AIEqualizerAudioFeatures
    ) -> AIEqualizerSpatialConfiguration {
        let deviceBase: (surround: Float, reverb: Float, width: Float)
        switch features.outputKind {
        case "wired", "usb":
            deviceBase = (0.14, 0.045, 1.10)
        case "bluetooth":
            deviceBase = (0.12, 0.04, 1.08)
        case "car":
            deviceBase = (0.09, 0.025, 1.06)
        case "airPlay":
            deviceBase = (0.08, 0.025, 1.06)
        case "builtInSpeaker":
            deviceBase = (0.035, 0.012, 1.02)
        default:
            deviceBase = (0.07, 0.025, 1.05)
        }

        let dynamicFactor = min(1, max(0, (features.dynamicSpreadDB - 4) / 10))
        let brightnessFactor = min(1, max(0, (features.spectralCentroidHz - 1_400) / 2_800))
        let densityPenalty = min(1, max(0, (features.spectralFlatness - 0.42) / 0.38))
        let surround = deviceBase.surround + 0.035 * dynamicFactor + 0.018 * brightnessFactor
        let reverb = deviceBase.reverb + 0.025 * dynamicFactor - 0.018 * densityPenalty
        let width = deviceBase.width + 0.035 * dynamicFactor - 0.02 * densityPenalty
        let minimumReverb: Float = features.outputKind == "builtInSpeaker" ? 0.01 : 0.015

        return AIEqualizerSpatialConfiguration(
            surroundLevel: min(0.24, max(0, surround)),
            reverbLevel: min(0.10, max(minimumReverb, reverb)),
            stereoWidth: min(1.16, max(1, width))
        )
    }

    private static func localizedProfileName(
        _ value: String,
        gains: [Float],
        spatial: AIEqualizerSpatialConfiguration
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidListeningProfileName(trimmed) { return trimmed }

        let lowAverage = gains.prefix(4).reduce(0, +) / 4
        let highAverage = gains.suffix(4).reduce(0, +) / 4
        if spatial.surroundLevel >= 0.16 {
            return String(localized: "ai_eq_profile_spatial")
        }
        if lowAverage - highAverage > 0.8 {
            return String(localized: "ai_eq_profile_bass")
        }
        if highAverage - lowAverage > 0.8 {
            return String(localized: "ai_eq_profile_clarity")
        }
        return String(localized: "ai_eq_profile_balanced")
    }

    private static func isValidListeningProfileName(_ value: String) -> Bool {
        guard isPrimarilyChinese(value) else { return false }

        let hanCount = value.unicodeScalars.reduce(into: 0) { count, scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                count += 1
            default:
                break
            }
        }
        guard (2...4).contains(hanCount),
              hanCount == value.unicodeScalars.count,
              value.count <= 4 else {
            return false
        }

        let forbiddenTerms = [
            "内置", "扬声器", "外放", "耳机", "蓝牙", "有线", "音箱", "音响",
            "车载", "汽车", "手机", "平板", "电脑", "设备", "输出", "连接",
            "USB", "AirPlay", "AirPods", "iPhone", "iPad", "Mac",
            "清晰", "通透", "平衡", "增强", "优化", "调音", "音效", "模式",
            "方案", "校准", "空间", "动态", "低频", "高频", "人声"
        ]
        return !forbiddenTerms.contains { term in
            value.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private static func localizedSummary(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return isPrimarilyChinese(trimmed)
            ? trimmed
            : String(localized: "ai_eq_summary_calibrated")
    }

    private static func isPrimarilyChinese(_ value: String) -> Bool {
        let hanCount = value.unicodeScalars.reduce(into: 0) { count, scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                count += 1
            default:
                break
            }
        }
        let latinCount = value.unicodeScalars.reduce(into: 0) { count, scalar in
            if (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value) {
                count += 1
            }
        }
        return hanCount >= 2 && latinCount <= max(2, hanCount / 2)
    }

    private static func validatedProfessional(
        _ value: AIEqualizerProfessionalConfiguration?
    ) -> AIEqualizerProfessionalConfiguration {
        let defaultDynamicBands = [
            AIEqualizerDynamicBandConfiguration(
                frequency: 72, q: 0.85, thresholdDB: -17, ratio: 1.7,
                maxReductionDB: 2.4, attackMS: 28, releaseMS: 190
            ),
            AIEqualizerDynamicBandConfiguration(
                frequency: 280, q: 1.05, thresholdDB: -19, ratio: 1.55,
                maxReductionDB: 1.8, attackMS: 35, releaseMS: 230
            ),
            AIEqualizerDynamicBandConfiguration(
                frequency: 7_200, q: 2.2, thresholdDB: -25, ratio: 2.3,
                maxReductionDB: 3, attackMS: 5, releaseMS: 95
            )
        ]
        let dynamicSource = value?.dynamicEQ.bands.isEmpty == false
            ? Array(value?.dynamicEQ.bands.prefix(6) ?? [])
            : defaultDynamicBands
        let dynamicBands = dynamicSource.map {
            AIEqualizerDynamicBandConfiguration(
                frequency: clampedFinite($0.frequency, fallback: 1_000, range: 20...20_000),
                q: clampedFinite($0.q, fallback: 1, range: 0.2...10),
                thresholdDB: clampedFinite($0.thresholdDB, fallback: -18, range: -60...0),
                ratio: clampedFinite($0.ratio, fallback: 1.5, range: 1...6),
                maxReductionDB: clampedFinite($0.maxReductionDB, fallback: 2, range: 0...6),
                attackMS: clampedFinite($0.attackMS, fallback: 20, range: 1...150),
                releaseMS: clampedFinite($0.releaseMS, fallback: 180, range: 20...800)
            )
        }

        let multibandSource = value?.multiband
        let multiband = AIEqualizerMultibandConfiguration(
            enabled: multibandSource?.enabled ?? true,
            lowCrossoverHz: clampedFinite(multibandSource?.lowCrossoverHz, fallback: 180, range: 60...600),
            highCrossoverHz: clampedFinite(multibandSource?.highCrossoverHz, fallback: 3_800, range: 1_200...10_000),
            thresholdsDB: normalizedTriplet(multibandSource?.thresholdsDB, fallback: [-13, -11, -15], range: -36 ... -4),
            ratios: normalizedTriplet(multibandSource?.ratios, fallback: [1.45, 1.28, 1.5], range: 1...4),
            maxReductionDB: normalizedTriplet(multibandSource?.maxReductionDB, fallback: [2.2, 1.5, 2], range: 0...6),
            attackMS: clampedFinite(multibandSource?.attackMS, fallback: 22, range: 1...150),
            releaseMS: clampedFinite(multibandSource?.releaseMS, fallback: 210, range: 20...800)
        )

        let supportedTypes = Set(["peak", "lowShelf", "highShelf", "lowPass", "highPass", "notch"])
        let parametricSource = Array(value?.parametricEQ.bands.prefix(8) ?? [])
        let parametricBands = parametricSource.map {
            AIEqualizerParametricBandConfiguration(
                type: supportedTypes.contains($0.type) ? $0.type : "peak",
                frequency: clampedFinite($0.frequency, fallback: 1_000, range: 20...20_000),
                gainDB: clampedFinite($0.gainDB, fallback: 0, range: -12...12),
                q: clampedFinite($0.q, fallback: 1, range: 0.1...12)
            )
        }

        return AIEqualizerProfessionalConfiguration(
            processingIntensity: clampedFinite(value?.processingIntensity, fallback: 1.3, range: 0.7...1.8),
            dynamicEQ: AIEqualizerDynamicEQConfiguration(
                enabled: value?.dynamicEQ.enabled ?? true,
                bands: dynamicBands
            ),
            multiband: multiband,
            parametricEQ: AIEqualizerParametricEQConfiguration(
                enabled: value?.parametricEQ.enabled ?? !parametricBands.isEmpty,
                bands: parametricBands
            )
        )
    }

    private static func normalizedTriplet(
        _ values: [Float]?,
        fallback: [Float],
        range: ClosedRange<Float>
    ) -> [Float] {
        guard let values, values.count == 3 else { return fallback }
        return zip(values, fallback).map {
            clampedFinite($0.0, fallback: $0.1, range: range)
        }
    }

    private static func clampedFinite(
        _ value: Float?,
        fallback: Float,
        range: ClosedRange<Float>
    ) -> Float {
        guard let value, value.isFinite else { return fallback }
        return min(range.upperBound, max(range.lowerBound, value))
    }
}

enum AIEqualizerSamplingMode: String, CaseIterable, Identifiable, Sendable {
    case smart
    case fast
    case deep
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return String(localized: "ai_sampling_smart")
        case .fast: return String(localized: "ai_sampling_fast")
        case .deep: return String(localized: "ai_sampling_deep")
        case .custom: return String(localized: "ai_sampling_custom")
        }
    }
}

enum AIEqualizerSamplingStage: String, Equatable, Sendable {
    case preparing
    case waitingForAudio
    case collectingSpectrum
    case measuringDynamics
    case organizingFeatures
    case finalizing

    var title: String {
        switch self {
        case .preparing: return String(localized: "ai_sampling_stage_preparing")
        case .waitingForAudio: return String(localized: "ai_sampling_stage_waiting")
        case .collectingSpectrum: return String(localized: "ai_sampling_stage_spectrum")
        case .measuringDynamics: return String(localized: "ai_sampling_stage_dynamics")
        case .organizingFeatures: return String(localized: "ai_sampling_stage_features")
        case .finalizing: return String(localized: "ai_sampling_stage_finalizing")
        }
    }
}

enum AIEqualizerGenerationStage: String, Equatable, Sendable {
    case preparing
    case generating
    case validating
    case finalizing

    var title: String {
        switch self {
        case .preparing: return String(localized: "ai_generation_stage_preparing")
        case .generating: return String(localized: "ai_generation_stage_generating")
        case .validating: return String(localized: "ai_generation_stage_validating")
        case .finalizing: return String(localized: "ai_generation_stage_finalizing")
        }
    }
}

enum AIEqualizerAgentPhase: Equatable, Sendable {
    case idle
    case sampling(progress: Double)
    case requesting
    case ready
    case applying
    case failed(String)

    var isWorking: Bool {
        switch self {
        case .sampling, .requesting, .applying: return true
        default: return false
        }
    }
}

enum AIEqualizerError: LocalizedError {
    case noSong
    case playbackRequired
    case sampleUnavailable
    case invalidEndpoint
    case missingAPIKey
    case modelUnavailable
    case invalidResponse
    case dailyLimitReached(Int)
    case hourlyLimitReached(Int)
    case requestFrequencyLimited(Int)
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .noSong: return String(localized: "ai_error_no_song")
        case .playbackRequired: return String(localized: "ai_error_playback_required")
        case .sampleUnavailable: return String(localized: "ai_error_sample_unavailable")
        case .invalidEndpoint: return String(localized: "ai_error_invalid_endpoint")
        case .missingAPIKey: return String(localized: "ai_error_missing_key")
        case .modelUnavailable: return String(localized: "ai_error_model_unavailable")
        case .invalidResponse: return String(localized: "ai_error_invalid_response")
        case let .dailyLimitReached(limit):
            return String(format: String(localized: "ai_error_daily_limit"), limit)
        case let .hourlyLimitReached(limit):
            return String(format: String(localized: "ai_error_hourly_limit"), limit)
        case let .requestFrequencyLimited(seconds):
            return String(format: String(localized: "ai_error_frequency_limit"), seconds)
        case let .httpStatus(code, message):
            return message.isEmpty ? "HTTP \(code)" : "HTTP \(code): \(message)"
        }
    }
}
