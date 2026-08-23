import Foundation

/// Versioned tuning knowledge shipped in the App bundle. Remote Agent
/// configuration may refine voicing, but cannot replace this evidence and DSP
/// ownership contract.
enum MonoAudioTuningKnowledge {
    struct Document: Decodable, Sendable {
        struct StageOwnership: Decodable, Sendable {
            let stage: String
            let owns: String
            let mustNotOwn: String
        }

        struct CapabilityOwnership: Decodable, Sendable {
            let owner: String
            let responsibility: String
        }

        struct UpstreamMethod: Decodable, Sendable {
            let source: String
            let method: String
            let decision: String
        }

        struct ToolPolicy: Decodable, Sendable {
            let minimumReliableSampleSeconds: Double
            let minimumReliableFrameCount: Int
            let lowEvidenceScore: Float
            let tenBandAdjacentDeltaDB: Float
            let thirtyTwoBandAdjacentDeltaDB: Float
            let tenBandMaximumParametricBands: Int
            let thirtyTwoBandMaximumParametricBands: Int
            let unsafePhaseCorrelation: Float
            let weakMonoCompatibility: Float
            let highTruePeakDBTP: Float
            let maximumLimiterCeilingDB: Float
            let uncertainLimiterCeilingDB: Float
            let maximumLowConfidenceGraphicPeakDB: Float
            let maximumLowConfidenceProcessingIntensity: Float
        }

        let schemaVersion: Int
        let knowledgeVersion: String
        let agentVersion: String
        let toolVersion: String
        let evidencePriority: [String]
        let stageOwnership: [StageOwnership]
        let contractRules: [String]
        let curveRules: [String]
        let dynamicsRules: [String]
        let stereoRules: [String]
        let deviceRules: [String]
        let runtimeRules: [String]
        let capabilityOwnership: [CapabilityOwnership]
        let upstreamMethods: [UpstreamMethod]
        let toolPolicy: ToolPolicy
        let verificationScenarios: [String]
    }

    static let document: Document = loadDocument()
    static var version: String { document.knowledgeVersion }
    static var agentVersion: String { document.agentVersion }
    static var toolVersion: String { document.toolVersion }
    static var enforcedRuleCount: Int {
        document.contractRules.count
            + document.curveRules.count
            + document.dynamicsRules.count
            + document.stereoRules.count
            + document.deviceRules.count
            + document.runtimeRules.count
    }
    static var modelRules: [String] {
        document.contractRules
            + document.curveRules
            + document.dynamicsRules
            + document.stereoRules
            + document.deviceRules
    }

    static var corePromptDirective: String {
        let evidence = document.evidencePriority.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let stages = document.stageOwnership
            .map { "- \($0.stage): owns \($0.owns); must not own \($0.mustNotOwn)." }
            .joined(separator: "\n")
        let operationalRules = [
            ("curve", document.curveRules),
            ("dynamics", document.dynamicsRules),
            ("stereo", document.stereoRules),
            ("device", document.deviceRules)
        ]
            .filter { !$0.1.isEmpty }
            .map { group, rules in
                "\(group): " + rules.joined(separator: " ")
            }
            .joined(separator: "\n")
        return """
        Built-in tuning knowledge: \(document.knowledgeVersion).
        Apply this evidence order; a lower-priority source can choose only between equally safe alternatives and can never override a higher-priority source:
        \(evidence)
        Keep processing ownership non-redundant:
        \(stages)
        Operational knowledge:
        \(operationalRules)
        """
    }

    /// Combines every input that can alter skill behavior into one bounded
    /// identity. The hash is deterministic across launches and does not depend
    /// on Swift's randomized `Hasher` implementation.
    static func executionFingerprint(
        runtimeFingerprint: String,
        runtimeRevision: String,
        toolPolicyRevision: String
    ) -> String {
        let source = [
            agentVersion,
            version,
            toolVersion,
            runtimeRevision,
            runtimeFingerprint,
            toolPolicyRevision
        ].joined(separator: "\u{1F}")
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "mono-skill-" + String(hash, radix: 16)
    }

    static func mandatoryContract(bandRequirement: String) -> String {
        let rules = document.contractRules.enumerated().map { index, rule in
            index == 0 ? "- \(rule) \(bandRequirement)" : "- \(rule)"
        }.joined(separator: "\n")
        return """
        Mandatory Mono DSP contract (\(document.knowledgeVersion)); it overrides any conflicting instruction above:
        \(rules)
        """
    }

    private static func loadDocument() -> Document {
        let urls: [URL?] = [
            Bundle.main.url(forResource: "mono_audio_tuning_knowledge", withExtension: "json"),
            Bundle.main.url(
                forResource: "mono_audio_tuning_knowledge",
                withExtension: "json",
                subdirectory: "Resources"
            )
        ]
        guard let url = urls.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Document.self, from: data),
              decoded.schemaVersion == 2,
              decoded.knowledgeVersion == "mono-tuning-knowledge-v2",
              decoded.agentVersion == "mono-audio-agent-v30-dsp",
              decoded.toolVersion == "mono-audio-tuning-tool-v1",
              !decoded.evidencePriority.isEmpty,
              !decoded.stageOwnership.isEmpty,
              !decoded.contractRules.isEmpty,
              !decoded.capabilityOwnership.isEmpty,
              !decoded.upstreamMethods.isEmpty else {
            AppLogger.warning("[MonoAudioTuningKnowledge] 内置知识包缺失或无效，使用编译期安全契约")
            return fallbackDocument
        }
        AppLogger.debug(
            "[MonoAudioTuningKnowledge] 已加载 \(decoded.knowledgeVersion)，阶段 \(decoded.stageOwnership.count) 个"
        )
        return decoded
    }

    private static let fallbackDocument = Document(
        schemaVersion: 2,
        knowledgeVersion: "mono-tuning-knowledge-v2",
        agentVersion: "mono-audio-agent-v30-dsp",
        toolVersion: "mono-audio-tuning-tool-v1",
        evidencePriority: [
            "Runtime clipping/render measurements and output route",
            "Local OPRA or device reference baseline",
            "Measured tonal, loudness, dynamics, transient, stereo, phase, and vocal evidence",
            "Explicit user request",
            "Confidence-bounded retained preference",
            "Metadata and model prior"
        ],
        stageOwnership: [
            .init(stage: "deviceBaseline", owns: "output-device correction", mustNotOwn: "track voicing"),
            .init(stage: "graphicEQ", owns: "broad tonal balance", mustNotOwn: "narrow or dynamic defects"),
            .init(stage: "parametricEQ", owns: "stable narrow defects", mustNotOwn: "speculative correction"),
            .init(stage: "dynamics", owns: "measured time-varying excess", mustNotOwn: "static balance"),
            .init(stage: "enhanceAndSpatial", owns: "bounded detail and width", mustNotOwn: "EQ duplication"),
            .init(stage: "preampAndLimiter", owns: "combined headroom", mustNotOwn: "loudness maximization")
        ],
        contractRules: [
            "Return exactly one schema-valid JSON object without Markdown.",
            "Runtime evidence and route state outrank preference and metadata.",
            "Never reproduce, invert, cancel, or expose the locally applied device baseline.",
            "Keep one non-redundant DSP chain and use at most one primary dynamics strategy.",
            "Use smooth evidence-backed curves; never mechanically invert band energy.",
            "Calculate headroom from every enabled positive-gain stage and uncertainty.",
            "Preserve phase, mono compatibility, centered bass, and stable vocals before widening.",
            "Low confidence produces a smaller move or omitted stage, never invented certainty."
        ],
        curveRules: [
            "Preserve the recording's identity; correction is not target-curve inversion.",
            "Ten-band curves own broad moves and normally keep adjacent jumps within 4.5 dB.",
            "Thirty-two-band curves use smooth local moves and normally keep adjacent jumps within 3 dB.",
            "One isolated low-energy band cannot justify a high-Q correction.",
            "Headroom covers positive graphic gain, tone, PEQ, spatial and enhancement contribution, dynamics makeup, and uncertainty."
        ],
        dynamicsRules: [
            "Preserve microdynamics with low ratios and bounded gain reduction.",
            "Clipping or a high true peak supports attenuation and containment, not automatic compression.",
            "A low crest factor alone does not justify more compression on an already dense master.",
            "Attack and release follow transient density and tempo without pumping.",
            "A seek, short analysis window, or low-confidence measurement cannot justify aggressive dynamics."
        ],
        stereoRules: [
            "Negative phase correlation or weak mono compatibility requires narrower width, lower Haas energy, and lower ambience.",
            "Keep low frequencies centered and vocals stable.",
            "Standard mode preserves the source image.",
            "Mono spatial mode may be wider, but never through unsafe phase tricks or excessive tails."
        ],
        deviceRules: [
            "MonoAcousticProfileEngine and the selected OPRA profile are the only output-device correction authority.",
            "The Agent receives device identity only as calibration context and never exposes it in a preset name or summary.",
            "The device reference curve is applied locally after per-track validation, then combined headroom is recalculated.",
            "A route or output-profile change invalidates results created for the previous output identity."
        ],
        runtimeRules: [
            "Keep render callbacks allocation-free and lock-free.",
            "Prepare coefficients, FFT buffers, resamplers, format conversion, JSON parsing, and network work away from the render thread.",
            "Smooth gain, frequency, Q, width, delay, wet-dry, and bypass changes to prevent zipper noise and discontinuities.",
            "Cancel stale analysis or generation work when song, source variant, route, profile, or graphic EQ mode changes.",
            "Never apply a result produced for another song, audio variant, route, profile, or graphic EQ mode.",
            "Avoid repeatedly reconfiguring AVAudioSession during steady playback.",
            "A missing or invalid knowledge resource falls back to the compiled safety contract instead of disabling validation."
        ],
        capabilityOwnership: [
            .init(owner: "AVFoundationCoreAudio", responsibility: "route, session, graph, and render path"),
            .init(owner: "MonoDSP", responsibility: "validated realtime processing"),
            .init(owner: "FFmpeg", responsibility: "decode and offline analysis"),
            .init(owner: "AIAgent", responsibility: "bounded parameter selection"),
            .init(owner: "MonoAudioTuningTool", responsibility: "local invocation, audit, and plan compilation")
        ],
        upstreamMethods: [
            .init(source: "OPRA", method: "device response correction", decision: "keep MonoAcousticProfileEngine authoritative")
        ],
        toolPolicy: .init(
            minimumReliableSampleSeconds: 18,
            minimumReliableFrameCount: 4_096,
            lowEvidenceScore: 0.55,
            tenBandAdjacentDeltaDB: 4.5,
            thirtyTwoBandAdjacentDeltaDB: 3,
            tenBandMaximumParametricBands: 6,
            thirtyTwoBandMaximumParametricBands: 3,
            unsafePhaseCorrelation: 0,
            weakMonoCompatibility: 0.45,
            highTruePeakDBTP: -1,
            maximumLimiterCeilingDB: -0.2,
            uncertainLimiterCeilingDB: -1,
            maximumLowConfidenceGraphicPeakDB: 4.5,
            maximumLowConfidenceProcessingIntensity: 1.25
        ),
        verificationScenarios: [
            "Low-confidence input stays conservative.",
            "Unsafe phase evidence disables unsafe widening.",
            "Device correction is not duplicated."
        ]
    )
}
