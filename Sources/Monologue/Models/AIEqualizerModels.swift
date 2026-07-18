import Foundation
import FFmpegSwiftSDK

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

struct AIEqualizerVocalReferenceFeatures: Codable, Equatable, Sendable {
    let confidence: Float
    let presence: Float
    let warmth: Float
    let brightness: Float
    let airiness: Float
    let dynamicExpression: Float
    let register: String
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
    let graphicEQMode: GraphicEQMode
    let bandFrequenciesHz: [Float]
    let bandEnergyDB: [Float]
    let spectralCentroidHz: Float
    let spectralRolloffHz: Float
    let rmsDBFS: Float
    let dynamicSpreadDB: Float
    let integratedLUFS: Float
    let shortTermLUFS: Float
    let momentaryLUFS: Float
    let loudnessRangeLU: Float
    let samplePeakDBFS: Float
    let estimatedTruePeakDBTP: Float
    let crestFactorDB: Float
    let dynamicRangeDR: Float
    let clippingRatio: Float
    let phaseCorrelation: Float
    let monoCompatibility: Float
    let measuredStereoWidth: Float
    let spectralFlatness: Float
    let spectralBandwidthHz: Float
    let spectralFlux: Float
    let lowEnergyRatio: Float
    let midEnergyRatio: Float
    let highEnergyRatio: Float
    let estimatedBPM: Float
    let tempoConfidence: Float
    let tempoStability: Float
    let estimatedKey: String
    let keyConfidence: Float
    let dominantPitchHz: Float
    let melodyRangeSemitones: Float
    let melodicActivity: Float
    let melodyContourHz: [Float]
    let transientDensity: Float
    let chroma: [Float]
    let genreHints: [String]
    let instrumentHints: [String]
    let vocalReference: AIEqualizerVocalReferenceFeatures?
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

enum AIEqualizerTuningIntensity: String, CaseIterable, Codable, Identifiable, Sendable {
    case smart
    case gentle
    case standard
    case strong

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return String(localized: "ai_tuning_intensity_smart")
        case .gentle: return String(localized: "ai_tuning_intensity_gentle")
        case .standard: return String(localized: "ai_tuning_intensity_standard")
        case .strong: return String(localized: "ai_tuning_intensity_strong")
        }
    }

    var promptDirective: String {
        switch self {
        case .smart:
            return "Choose the intervention strength from the measurements. Prefer the least processing that produces a useful audible correction, and never exceed the global safety ranges."
        case .gentle:
            return "Use gentle intervention. Preserve the original tonal balance, dynamics, ambience, and transients. Prefer subtle corrections: graphic EQ within about ±4.5 dB, tone within ±3 dB, restrained spatial processing, and low professional-processing intensity."
        case .standard:
            return "Use standard intervention. Produce a clearly useful but balanced correction: graphic EQ within about ±6.5 dB, tone within ±5 dB, moderate spatial processing, and moderate professional-processing intensity."
        case .strong:
            return "Use strong intervention. The result may be clearly audible across tone, space, and dynamics, while still preserving headroom, phase safety, transient integrity, and the recording's identity. Do not use loudness as a substitute for quality."
        }
    }

    fileprivate var graphicGainRange: ClosedRange<Float> {
        switch self {
        case .gentle: return -4.5...4.5
        case .standard: return -6.5...6.5
        case .smart, .strong: return -9...9
        }
    }

    fileprivate var toneRange: ClosedRange<Float> {
        switch self {
        case .gentle: return -3...3
        case .standard: return -5...5
        case .smart, .strong: return -8...8
        }
    }

    fileprivate var surroundRange: ClosedRange<Float> {
        switch self {
        case .gentle: return 0...0.18
        case .standard: return 0...0.42
        case .smart, .strong: return 0...0.85
        }
    }

    fileprivate var reverbRange: ClosedRange<Float> {
        switch self {
        case .gentle: return 0...0.10
        case .standard: return 0...0.26
        case .smart, .strong: return 0...0.6
        }
    }

    fileprivate var stereoWidthRange: ClosedRange<Float> {
        switch self {
        case .gentle: return 0.86...1.14
        case .standard: return 0.76...1.38
        case .smart, .strong: return 0.65...1.75
        }
    }

    fileprivate var processingIntensityRange: ClosedRange<Float> {
        switch self {
        case .gentle: return 0.6...1.0
        case .standard: return 0.85...1.45
        case .strong: return 1.2...1.9
        case .smart: return 0.6...2.1
        }
    }

    fileprivate var defaultProcessingIntensity: Float {
        switch self {
        case .smart: return 1.3
        case .gentle: return 0.82
        case .standard: return 1.15
        case .strong: return 1.55
        }
    }

    fileprivate var dynamicRatioMaximum: Float {
        switch self {
        case .gentle: return 2.2
        case .standard: return 4
        case .smart, .strong: return 8
        }
    }

    fileprivate var dynamicReductionMaximum: Float {
        switch self {
        case .gentle: return 2.5
        case .standard: return 4.5
        case .smart, .strong: return 8
        }
    }

    fileprivate var enhancementGainMaximum: Float {
        switch self {
        case .gentle: return 3
        case .standard: return 5
        case .smart, .strong: return 8
        }
    }
}

struct AIEqualizerTiming: Codable, Equatable, Sendable {
    let total: TimeInterval
    let sampling: TimeInterval
    let generation: TimeInterval
    let applying: TimeInterval
    let completedAt: Date
}

enum AIEqualizerLearningFeedback: String, Codable, Equatable, Sendable {
    case positive
    case negative
    case reset
    case regenerated
    case retained
}

/// A compact, bounded policy produced from prior tuning outcomes. Raw audio is
/// never retained: only small parameter corrections and aggregate confidence
/// are allowed to influence a future proposal.
struct AIEqualizerLearningContext: Codable, Equatable, Sendable {
    let revision: Int
    let evidenceCount: Int
    let confidence: Float
    let bandAdjustments: [Float]
    let bassAdjustment: Float
    let trebleAdjustment: Float
    let surroundAdjustment: Float
    let reverbAdjustment: Float
    let stereoWidthAdjustment: Float
    let processingIntensityAdjustment: Float

    var isActive: Bool {
        evidenceCount > 0 && confidence >= 0.04
    }
}

struct AIEqualizerModelOutput: Decodable, Equatable, Sendable {
    let profileName: String
    let gains: [Float]
    let preampDB: Float
    let tone: AIEqualizerToneConfiguration?
    let spatial: AIEqualizerSpatialConfiguration?
    let calibration: AIEqualizerCalibrationConfiguration?
    let professional: AIEqualizerProfessionalConfiguration?
    let effects: MonoEffectTuningConfiguration?
    let confidence: Float
    let summary: String
    let artistStyleReference: String
    let vocalCharacterReference: String

    private enum CodingKeys: String, CodingKey {
        case profileName
        case gains
        case preampDB
        case tone
        case spatial
        case calibration
        case professional
        case effects
        case confidence
        case summary
        case artistStyleReference
        case vocalCharacterReference
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        profileName = try values.decodeIfPresent(String.self, forKey: .profileName) ?? ""
        gains = try values.decode([Float].self, forKey: .gains)
        preampDB = try values.decodeIfPresent(Float.self, forKey: .preampDB) ?? 0

        // A partially emitted optional section should not invalidate the core EQ
        // curve. Proposal validation supplies safe defaults for that section.
        tone = try? values.decode(AIEqualizerToneConfiguration.self, forKey: .tone)
        spatial = try? values.decode(AIEqualizerSpatialConfiguration.self, forKey: .spatial)
        calibration = try? values.decode(AIEqualizerCalibrationConfiguration.self, forKey: .calibration)
        professional = try? values.decode(AIEqualizerProfessionalConfiguration.self, forKey: .professional)
        effects = try? values.decode(MonoEffectTuningConfiguration.self, forKey: .effects)

        confidence = try values.decodeIfPresent(Float.self, forKey: .confidence) ?? 0.65
        summary = try values.decodeIfPresent(String.self, forKey: .summary) ?? ""
        artistStyleReference = try values.decodeIfPresent(String.self, forKey: .artistStyleReference) ?? ""
        vocalCharacterReference = try values.decodeIfPresent(String.self, forKey: .vocalCharacterReference) ?? ""
    }
}

struct AIEqualizerProposal: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let songID: Int
    let profileName: String
    let graphicEQMode: GraphicEQMode
    let gains: [Float]
    let preampDB: Float
    let tone: AIEqualizerToneConfiguration
    let spatial: AIEqualizerSpatialConfiguration
    let calibration: AIEqualizerCalibrationConfiguration
    let professional: AIEqualizerProfessionalConfiguration
    let effects: MonoEffectTuningConfiguration
    let confidence: Float
    let summary: String
    let artistStyleReference: String?
    let vocalCharacterReference: String?
    let provider: AIWireProtocol
    let model: String
    let agentVersion: String?
    let learningRevision: Int?
    let learningConfidence: Float?
    let learningEvidenceCount: Int?
    let createdAt: Date
    let tuningIntensity: AIEqualizerTuningIntensity?
    var timing: AIEqualizerTiming?

    init(
        songID: Int,
        output: AIEqualizerModelOutput,
        features: AIEqualizerAudioFeatures,
        provider: AIWireProtocol,
        model: String,
        agentVersion: String,
        tuningIntensity: AIEqualizerTuningIntensity = .smart,
        avoidingProfileNames: Set<String> = [],
        learningContext: AIEqualizerLearningContext? = nil
    ) {
        let baseGains = Self.validatedGains(
            output.gains,
            mode: features.graphicEQMode,
            intensity: tuningIntensity
        )
        let learnedBandAdjustments = learningContext?.isActive == true
            ? features.graphicEQMode.normalizedGains(
                learningContext?.bandAdjustments ?? [],
                limit: 1.25
            )
            : Array(repeating: 0, count: features.graphicEQMode.bandCount)
        let normalized = Self.validatedGains(
            zip(baseGains, learnedBandAdjustments).map { pair in pair.0 + pair.1 },
            mode: features.graphicEQMode,
            intensity: tuningIntensity
        )

        let baseTone = Self.validatedTone(output.tone, intensity: tuningIntensity)
        let resolvedTone = Self.validatedTone(
            AIEqualizerToneConfiguration(
                bassGain: baseTone.bassGain + (learningContext?.bassAdjustment ?? 0),
                trebleGain: baseTone.trebleGain + (learningContext?.trebleAdjustment ?? 0)
            ),
            intensity: tuningIntensity
        )
        let baseSpatial = Self.validatedSpatial(
            output.spatial,
            features: features,
            intensity: tuningIntensity
        )
        let resolvedSpatial = Self.validatedSpatial(
            AIEqualizerSpatialConfiguration(
                surroundLevel: baseSpatial.surroundLevel + (learningContext?.surroundAdjustment ?? 0),
                reverbLevel: baseSpatial.reverbLevel + (learningContext?.reverbAdjustment ?? 0),
                stereoWidth: baseSpatial.stereoWidth + (learningContext?.stereoWidthAdjustment ?? 0)
            ),
            features: features,
            intensity: tuningIntensity
        )
        let baseProfessional = Self.validatedProfessional(
            output.professional,
            features: features,
            intensity: tuningIntensity
        )
        let resolvedProfessional = AIEqualizerProfessionalConfiguration(
            processingIntensity: min(
                tuningIntensity.processingIntensityRange.upperBound,
                max(
                    tuningIntensity.processingIntensityRange.lowerBound,
                    baseProfessional.processingIntensity
                        + (learningContext?.processingIntensityAdjustment ?? 0)
                )
            ),
            dynamicEQ: baseProfessional.dynamicEQ,
            multiband: baseProfessional.multiband,
            parametricEQ: baseProfessional.parametricEQ
        )
        let resolvedEffects = Self.validatedEffects(
            output.effects,
            features: features,
            professional: resolvedProfessional,
            intensity: tuningIntensity
        )
        let graphicPeak = max(0, normalized.max() ?? 0)
        let tonePeak = max(0, max(resolvedTone.bassGain, resolvedTone.trebleGain)) * 0.55
        let spatialReserve = resolvedSpatial.surroundLevel * 1.2
            + resolvedSpatial.reverbLevel
            + max(0, resolvedSpatial.stereoWidth - 1) * 1.5
        let enhancementReserve = resolvedEffects.subboostGainDB * 0.45
            + resolvedEffects.virtualBassStrength * 0.25
            + resolvedEffects.exciterAmountDB * 0.18
            + max(0, resolvedEffects.compressorMakeupDB)
        let requiredHeadroom = -min(
            18,
            graphicPeak + tonePeak + spatialReserve + enhancementReserve + 0.75
        )

        id = UUID()
        self.songID = songID
        graphicEQMode = features.graphicEQMode
        profileName = Self.localizedProfileName(
            output.profileName,
            gains: normalized,
            spatial: resolvedSpatial,
            features: features,
            avoiding: avoidingProfileNames
        )
        gains = normalized
        preampDB = min(0, max(-18, min(output.preampDB, requiredHeadroom)))
        tone = resolvedTone
        spatial = resolvedSpatial
        calibration = output.calibration ?? AIEqualizerCalibrationConfiguration(
            outputCalibrationEnabled: true,
            loudnessMatchingEnabled: true,
            smartSongCompensationEnabled: true
        )
        professional = resolvedProfessional
        effects = resolvedEffects
        confidence = min(1, max(0, output.confidence))
        let resolvedArtistReference = Self.localizedReference(output.artistStyleReference)
        let resolvedVocalReference = Self.localizedReference(output.vocalCharacterReference)
        artistStyleReference = resolvedArtistReference
        vocalCharacterReference = resolvedVocalReference
        summary = Self.resolvedSummary(
            output.summary,
            artistStyleReference: resolvedArtistReference,
            vocalCharacterReference: resolvedVocalReference
        )
        self.provider = provider
        self.model = model
        self.agentVersion = agentVersion
        learningRevision = learningContext?.revision
        learningConfidence = learningContext?.isActive == true ? learningContext?.confidence : nil
        learningEvidenceCount = learningContext?.isActive == true ? learningContext?.evidenceCount : nil
        createdAt = Date()
        self.tuningIntensity = tuningIntensity
        timing = nil
    }

    private static func validatedGains(
        _ values: [Float],
        mode: GraphicEQMode,
        intensity: AIEqualizerTuningIntensity
    ) -> [Float] {
        var result = Array(values.prefix(mode.bandCount)).map { value -> Float in
            guard value.isFinite else { return 0 }
            return min(intensity.graphicGainRange.upperBound, max(intensity.graphicGainRange.lowerBound, value))
        }
        if result.count < mode.bandCount {
            result.append(contentsOf: repeatElement(Float(0), count: mode.bandCount - result.count))
        }
        let maximumAdjacentDelta: Float
        switch intensity {
        case .gentle:
            maximumAdjacentDelta = mode == .thirtyTwoBand ? 1.8 : 2.7
        case .standard:
            maximumAdjacentDelta = mode == .thirtyTwoBand ? 2.4 : 3.7
        case .smart, .strong:
            maximumAdjacentDelta = mode == .thirtyTwoBand ? 3 : 4.5
        }
        for index in 1..<result.count {
            result[index] = min(
                result[index - 1] + maximumAdjacentDelta,
                max(result[index - 1] - maximumAdjacentDelta, result[index])
            )
        }
        if result.count > 1 {
            for index in stride(from: result.count - 2, through: 0, by: -1) {
                result[index] = min(
                    result[index + 1] + maximumAdjacentDelta,
                    max(result[index + 1] - maximumAdjacentDelta, result[index])
                )
            }
        }
        return result
    }

    private static func validatedTone(
        _ value: AIEqualizerToneConfiguration?,
        intensity: AIEqualizerTuningIntensity
    ) -> AIEqualizerToneConfiguration {
        AIEqualizerToneConfiguration(
            bassGain: clampedFinite(value?.bassGain, fallback: 0, range: intensity.toneRange),
            trebleGain: clampedFinite(value?.trebleGain, fallback: 0, range: intensity.toneRange)
        )
    }

    private static func validatedSpatial(
        _ value: AIEqualizerSpatialConfiguration?,
        features: AIEqualizerAudioFeatures,
        intensity: AIEqualizerTuningIntensity
    ) -> AIEqualizerSpatialConfiguration {
        let proposedSurround = clampedFinite(value?.surroundLevel, fallback: 0, range: intensity.surroundRange)
        let proposedReverb = clampedFinite(value?.reverbLevel, fallback: 0, range: intensity.reverbRange)
        let proposedWidth = clampedFinite(value?.stereoWidth, fallback: 1, range: intensity.stereoWidthRange)
        let fallback = spatialFallback(for: features)

        return AIEqualizerSpatialConfiguration(
            surroundLevel: proposedSurround <= 0.005
                ? min(intensity.surroundRange.upperBound, fallback.surroundLevel)
                : proposedSurround,
            reverbLevel: proposedReverb <= 0.005
                ? min(intensity.reverbRange.upperBound, fallback.reverbLevel)
                : proposedReverb,
            stereoWidth: abs(proposedWidth - 1) <= 0.005
                ? min(intensity.stereoWidthRange.upperBound, max(intensity.stereoWidthRange.lowerBound, fallback.stereoWidth))
                : proposedWidth
        )
    }

    private static func validatedEffects(
        _ value: MonoEffectTuningConfiguration?,
        features: AIEqualizerAudioFeatures,
        professional: AIEqualizerProfessionalConfiguration,
        intensity: AIEqualizerTuningIntensity
    ) -> MonoEffectTuningConfiguration {
        guard let value else {
            return MonoEffectTuningConfiguration(finalLimiterEnabled: true)
        }

        let supportsHeadphoneSpatial = ["wired", "bluetooth", "usb"].contains(features.outputKind)
        let bs2bEnabled = supportsHeadphoneSpatial && value.bs2bEnabled
        var crossfeedEnabled = supportsHeadphoneSpatial && value.crossfeedEnabled
        if bs2bEnabled && crossfeedEnabled {
            // Both solve the same headphone-crosstalk problem. Avoid stacking.
            crossfeedEnabled = false
        }
        let phaseSafe = features.phaseCorrelation >= 0.05 && features.monoCompatibility >= 0.45
        let haasEnabled = value.haasEnabled && phaseSafe && !bs2bEnabled && !crossfeedEnabled

        var subboostEnabled = value.subboostEnabled
        var virtualBassEnabled = value.virtualBassEnabled
        if subboostEnabled && virtualBassEnabled {
            if features.outputKind == "builtInSpeaker" {
                subboostEnabled = false
            } else {
                virtualBassEnabled = false
            }
        }

        return MonoEffectTuningConfiguration(
            // Offline-style loudnorm is not safe in Mono's realtime render
            // chain. Measured loudness matching and the final limiter cover it.
            loudnessNormalizationEnabled: false,
            targetLUFS: clampedFinite(value.targetLUFS, fallback: -14, range: -24 ... -9),
            targetLRA: clampedFinite(value.targetLRA, fallback: 9, range: 3...18),
            truePeakCeilingDB: clampedFinite(value.truePeakCeilingDB, fallback: -1, range: -3 ... -0.2),
            compressorEnabled: value.compressorEnabled
                && !professional.dynamicEQ.enabled
                && !professional.multiband.enabled,
            compressorThresholdDB: clampedFinite(value.compressorThresholdDB, fallback: -18, range: -36 ... -4),
            compressorRatio: clampedFinite(
                value.compressorRatio,
                fallback: 2,
                range: 1...min(6, intensity.dynamicRatioMaximum)
            ),
            compressorAttackMS: clampedFinite(value.compressorAttackMS, fallback: 18, range: 1...200),
            compressorReleaseMS: clampedFinite(value.compressorReleaseMS, fallback: 180, range: 30...1_200),
            compressorMakeupDB: clampedFinite(
                value.compressorMakeupDB,
                fallback: 0,
                range: -min(3, intensity.enhancementGainMaximum)...min(6, intensity.enhancementGainMaximum)
            ),
            subboostEnabled: subboostEnabled,
            subboostGainDB: clampedFinite(
                value.subboostGainDB,
                fallback: 0,
                range: 0...intensity.enhancementGainMaximum
            ),
            subboostCutoffHz: clampedFinite(value.subboostCutoffHz, fallback: 90, range: 40...180),
            bs2bEnabled: bs2bEnabled,
            bs2bCutoffHz: min(1_500, max(400, value.bs2bCutoffHz)),
            bs2bFeed: min(100, max(10, value.bs2bFeed)),
            crossfeedEnabled: crossfeedEnabled,
            crossfeedStrength: clampedFinite(value.crossfeedStrength, fallback: 0.2, range: 0...0.55),
            haasEnabled: haasEnabled,
            haasDelayMS: clampedFinite(value.haasDelayMS, fallback: 12, range: 1...25),
            virtualBassEnabled: virtualBassEnabled,
            virtualBassCutoffHz: clampedFinite(value.virtualBassCutoffHz, fallback: 180, range: 80...320),
            virtualBassStrength: clampedFinite(
                value.virtualBassStrength,
                fallback: 0,
                range: 0...min(6, intensity.enhancementGainMaximum)
            ),
            exciterEnabled: value.exciterEnabled,
            exciterAmountDB: clampedFinite(
                value.exciterAmountDB,
                fallback: 0,
                range: 0...min(6, intensity.enhancementGainMaximum)
            ),
            exciterFrequencyHz: clampedFinite(value.exciterFrequencyHz, fallback: 7_500, range: 3_000...14_000),
            softclipEnabled: value.softclipEnabled,
            softclipType: min(7, max(0, value.softclipType)),
            finalLimiterEnabled: value.finalLimiterEnabled,
            finalLimiterCeilingDB: clampedFinite(value.finalLimiterCeilingDB, fallback: -1, range: -3 ... -0.2)
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
        spatial: AIEqualizerSpatialConfiguration,
        features: AIEqualizerAudioFeatures,
        avoiding recentNames: Set<String>
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidListeningProfileName(trimmed), !recentNames.contains(trimmed) {
            return trimmed
        }

        let edgeCount = max(2, min(6, gains.count / 4))
        let lowAverage = gains.prefix(edgeCount).reduce(0, +) / Float(edgeCount)
        let highAverage = gains.suffix(edgeCount).reduce(0, +) / Float(edgeCount)
        let preferredNames: [String]
        if spatial.surroundLevel >= 0.16 {
            preferredNames = ["远岫", "长空", "云境", "旷野", "天际", "浮屿", "星野", "风岸"]
        } else if lowAverage - highAverage > 0.8 {
            preferredNames = ["沉潮", "暗涌", "深湾", "夜航", "玄浪", "厚土", "潜流", "暮鼓"]
        } else if highAverage - lowAverage > 0.8 {
            preferredNames = ["清辉", "晨星", "霁光", "银汉", "晴岚", "星芒", "初霁", "月白"]
        } else if features.dynamicSpreadDB >= 11 {
            preferredNames = ["奔流", "跃浪", "疾风", "燃点", "潮汐", "飞驰", "破晓", "脉动"]
        } else if features.rmsDBFS <= -20 {
            preferredNames = ["轻雾", "微醺", "暮云", "静月", "薄暮", "余温", "绒夜", "夜雨"]
        } else if features.spectralFlatness >= 0.58 {
            preferredNames = ["墨影", "近景", "暗纹", "凝夜", "黑曜", "深墨", "静帧", "暮影"]
        } else {
            preferredNames = ["和风", "素月", "晴川", "松间", "微光", "流云", "静流", "青岚"]
        }

        return fallbackProfileName(
            preferredNames: preferredNames,
            features: features,
            avoiding: recentNames
        )
    }

    private static func fallbackProfileName(
        preferredNames: [String],
        features: AIEqualizerAudioFeatures,
        avoiding recentNames: Set<String>
    ) -> String {
        let allNames = preferredNames + [
            "远岫", "长空", "星野", "沉潮", "暗涌", "夜航", "清辉", "晨星",
            "霁光", "晴岚", "奔流", "潮汐", "破晓", "轻雾", "暮云", "静月",
            "墨影", "暗纹", "黑曜", "和风", "素月", "晴川", "松间", "流云"
        ].filter { !preferredNames.contains($0) }
        let seedText = "\(features.source)|\(features.songID)|\(features.title)|\(features.artist)"
        let seed = seedText.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
        let startIndex = Int(seed % UInt64(allNames.count))

        for offset in allNames.indices {
            let candidate = allNames[(startIndex + offset) % allNames.count]
            if !recentNames.contains(candidate) { return candidate }
        }
        return allNames[startIndex]
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
            "方案", "校准", "空间", "动态", "低频", "高频", "人声", "音色",
            "声场", "质感", "层次", "沉浸", "自然", "明亮", "饱满", "细腻", "顺滑"
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

    private static func resolvedSummary(
        _ value: String,
        artistStyleReference: String?,
        vocalCharacterReference: String?
    ) -> String {
        let base = localizedSummary(value)
        let references = [
            artistStyleReference.map { "歌手参考：\($0)" },
            vocalCharacterReference.map { "演唱参考：\($0)" }
        ]
        .compactMap { $0 }
        .filter { reference in
            !base.localizedCaseInsensitiveContains(
                reference.replacingOccurrences(of: "歌手参考：", with: "")
                    .replacingOccurrences(of: "演唱参考：", with: "")
            )
        }
        guard !references.isEmpty else { return base }
        return "\(base)\n\(references.joined(separator: " · "))"
    }

    private static func localizedReference(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 48,
              isPrimarilyChinese(trimmed) else { return nil }
        return trimmed
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
        _ value: AIEqualizerProfessionalConfiguration?,
        features: AIEqualizerAudioFeatures,
        intensity: AIEqualizerTuningIntensity
    ) -> AIEqualizerProfessionalConfiguration {
        let dynamicBandLimit = features.graphicEQMode == .thirtyTwoBand ? 3 : 4
        let parametricBandLimit = features.graphicEQMode == .thirtyTwoBand ? 3 : 6
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
            ? Array(value?.dynamicEQ.bands.prefix(dynamicBandLimit) ?? [])
            : Array(defaultDynamicBands.prefix(dynamicBandLimit))
        let dynamicBands = dynamicSource.map {
            AIEqualizerDynamicBandConfiguration(
                frequency: clampedFinite($0.frequency, fallback: 1_000, range: 20...20_000),
                q: clampedFinite($0.q, fallback: 1, range: 0.15...12),
                thresholdDB: clampedFinite($0.thresholdDB, fallback: -18, range: -60...0),
                ratio: clampedFinite(
                    $0.ratio,
                    fallback: 1.5,
                    range: 1...intensity.dynamicRatioMaximum
                ),
                maxReductionDB: clampedFinite(
                    $0.maxReductionDB,
                    fallback: 2,
                    range: 0...intensity.dynamicReductionMaximum
                ),
                attackMS: clampedFinite($0.attackMS, fallback: 20, range: 0.5...200),
                releaseMS: clampedFinite($0.releaseMS, fallback: 180, range: 15...1_000)
            )
        }

        let multibandSource = value?.multiband
        let dynamicEnabled = value?.dynamicEQ.enabled ?? true
        let multibandEnabled = (multibandSource?.enabled ?? false) && !dynamicEnabled
        let multiband = AIEqualizerMultibandConfiguration(
            enabled: multibandEnabled,
            lowCrossoverHz: clampedFinite(multibandSource?.lowCrossoverHz, fallback: 180, range: 60...600),
            highCrossoverHz: clampedFinite(multibandSource?.highCrossoverHz, fallback: 3_800, range: 1_200...10_000),
            thresholdsDB: normalizedTriplet(multibandSource?.thresholdsDB, fallback: [-13, -11, -15], range: -36 ... -4),
            ratios: normalizedTriplet(
                multibandSource?.ratios,
                fallback: [1.45, 1.28, 1.5],
                range: 1...min(6, intensity.dynamicRatioMaximum)
            ),
            maxReductionDB: normalizedTriplet(
                multibandSource?.maxReductionDB,
                fallback: [2.2, 1.5, 2],
                range: 0...intensity.dynamicReductionMaximum
            ),
            attackMS: clampedFinite(multibandSource?.attackMS, fallback: 22, range: 0.5...200),
            releaseMS: clampedFinite(multibandSource?.releaseMS, fallback: 210, range: 15...1_000)
        )

        let supportedTypes = Set(["peak", "lowShelf", "highShelf", "lowPass", "highPass", "notch"])
        let parametricSource = Array(value?.parametricEQ.bands.prefix(parametricBandLimit) ?? [])
        let parametricBands = parametricSource.map {
            AIEqualizerParametricBandConfiguration(
                type: supportedTypes.contains($0.type) ? $0.type : "peak",
                frequency: clampedFinite($0.frequency, fallback: 1_000, range: 20...20_000),
                gainDB: clampedFinite(
                    $0.gainDB,
                    fallback: 0,
                    range: -min(12, intensity.graphicGainRange.upperBound)...min(12, intensity.graphicGainRange.upperBound)
                ),
                q: clampedFinite($0.q, fallback: 1, range: 0.1...12)
            )
        }

        return AIEqualizerProfessionalConfiguration(
            processingIntensity: clampedFinite(
                value?.processingIntensity,
                fallback: intensity.defaultProcessingIntensity,
                range: intensity.processingIntensityRange
            ),
            dynamicEQ: AIEqualizerDynamicEQConfiguration(
                enabled: dynamicEnabled,
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

/// A persisted AI tuning result. The cache key is intentionally separate from
/// this record: one song can keep multiple generations for comparison while
/// the cache still selects the best exact match for the current settings.
struct AIEqualizerSavedProposal: Identifiable, Codable, Equatable, Sendable {
    let proposal: AIEqualizerProposal
    let songIdentifier: String
    let outputIdentity: String

    var id: UUID { proposal.id }
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
