import Foundation
import FFmpegSwiftSDK

/// Deterministic local tool used by the tuning Agent before and after model
/// generation. The model proposes taste; this tool owns evidence constraints,
/// output auditing, local normalization, and final safety acceptance.
enum MonoAudioTuningTool {
    enum Severity: String, Sendable {
        case warning
        case rejection
    }

    struct Issue: Sendable {
        let code: String
        let severity: Severity
        let detail: String
    }

    struct Review: Sendable {
        let issues: [Issue]

        var isAccepted: Bool {
            !issues.contains { $0.severity == .rejection }
        }

        var summary: String {
            guard !issues.isEmpty else { return "通过" }
            return issues.map { "\($0.severity.rawValue):\($0.code)" }
                .joined(separator: ",")
        }
    }

    struct InvocationContext: Codable, Sendable {
        let tool: String
        let knowledge: String
        let graphicEQMode: String
        let expectedBandCount: Int
        let expectedFrequenciesHz: [Float]
        let maximumAdjacentDeltaDB: Float
        let maximumParametricBands: Int
        let evidenceScore: Float
        let evidenceClass: String
        let peakRisk: String
        let phaseRisk: String
        let outputKind: String
        let deviceBaselineAppliedLocally: Bool
        let deviceDisplayName: String?
        let allowedPrimaryDynamicsStrategies: [String]
        let haasAllowed: Bool
        let maximumLimiterCeilingDB: Float
        let mandatoryRules: [String]
        let enabledSkillIDs: [String]
        let requiredSkillIDs: [String]
        let artistReferenceAllowed: Bool
        let vocalReferenceAllowed: Bool
    }

    static var version: String { MonoAudioTuningKnowledge.toolVersion }

    static func requiredModelTool(for mode: GraphicEQMode) -> AIRequiredTool {
        let bandCount = mode.bandCount
        let parameters = """
        {
          "type":"object",
          "additionalProperties":false,
          "required":["profileName","gains","preampDB","tone","spatial","enhance","calibration","professional","effects","confidence","artistStyleReference","vocalCharacterReference","summary"],
          "properties":{
            "profileName":{"type":"string"},
            "gains":{"type":"array","minItems":\(bandCount),"maxItems":\(bandCount),"items":{"type":"number","minimum":-9,"maximum":9}},
            "preampDB":{"type":"number","minimum":-18,"maximum":0},
            "tone":{"type":"object"},
            "spatial":{"type":"object"},
            "enhance":{"type":"object"},
            "calibration":{"type":"object"},
            "professional":{"type":"object"},
            "effects":{"type":"object"},
            "confidence":{"type":"number","minimum":0,"maximum":1},
            "artistStyleReference":{"type":"string"},
            "vocalCharacterReference":{"type":"string"},
            "summary":{"type":"string"}
          }
        }
        """
        return AIRequiredTool(
            name: "mono_audio_tuning",
            description: "Submit the final complete Mono playback-tuning plan. Call exactly once after evaluating measurements and active Agent skills. The call arguments are validated and compiled locally as the final result.",
            parametersJSON: parameters
        )
    }

    /// Prepares the deterministic policy before the network request without
    /// serializing it into the model prompt. This keeps tool validation in the
    /// generation path while avoiding extra request tokens and latency.
    static func prepareInvocation(
        features: AIEqualizerAudioFeatures,
        tuningProfile: AIEqualizerTuningProfile,
        deviceTuningTarget: AIEqualizerDeviceTuningTarget?,
        skillRuntime: MonoAudioAgentRuntimeSkillConfiguration
    ) -> InvocationContext {
        invocationContext(
            features: features,
            tuningProfile: tuningProfile,
            deviceTuningTarget: deviceTuningTarget,
            skillRuntime: skillRuntime
        )
    }

    static func review(
        output: AIEqualizerModelOutput,
        features: AIEqualizerAudioFeatures,
        tuningProfile: AIEqualizerTuningProfile,
        deviceTuningTarget: AIEqualizerDeviceTuningTarget?,
        skillRuntime: MonoAudioAgentRuntimeSkillConfiguration
    ) -> Review {
        let context = invocationContext(
            features: features,
            tuningProfile: tuningProfile,
            deviceTuningTarget: deviceTuningTarget,
            skillRuntime: skillRuntime
        )
        return review(output: output, features: features, context: context)
    }

    static func review(
        output: AIEqualizerModelOutput,
        features: AIEqualizerAudioFeatures,
        context: InvocationContext
    ) -> Review {
        let policy = MonoAudioTuningKnowledge.document.toolPolicy
        var issues: [Issue] = []

        if output.gains.count != features.graphicEQMode.bandCount {
            issues.append(.init(
                code: "band-count",
                severity: .rejection,
                detail: "均衡器频段数量与当前模式不一致"
            ))
        }
        if !output.gains.allSatisfy(\.isFinite)
            || !output.preampDB.isFinite
            || !output.confidence.isFinite {
            issues.append(.init(
                code: "non-finite",
                severity: .rejection,
                detail: "模型返回了不可用的数值"
            ))
        }

        if maximumAdjacentDelta(output.gains) > context.maximumAdjacentDeltaDB + 0.001 {
            issues.append(.init(
                code: "curve-discontinuity",
                severity: .warning,
                detail: "相邻频段跳变过大，将由本地编译器平滑"
            ))
        }

        if let professional = output.professional {
            if professional.dynamicEQ.enabled && professional.multiband.enabled {
                issues.append(.init(
                    code: "duplicate-dynamics",
                    severity: .warning,
                    detail: "动态均衡与多段动态重复，本地仅保留一种主动态策略"
                ))
            }
            if professional.parametricEQ.bands.count > context.maximumParametricBands {
                issues.append(.init(
                    code: "peq-band-limit",
                    severity: .warning,
                    detail: "参数均衡频段过多，本地将按当前图示均衡模式裁剪"
                ))
            }
            if context.evidenceClass == "low",
               professional.processingIntensity > policy.maximumLowConfidenceProcessingIntensity {
                issues.append(.init(
                    code: "low-evidence-intensity",
                    severity: .warning,
                    detail: "低可信测量下处理强度过高，本地将收敛参数"
                ))
            }
        }

        let graphicPeak = output.gains.map(abs).max() ?? 0
        if context.evidenceClass == "low",
           graphicPeak > policy.maximumLowConfidenceGraphicPeakDB {
            issues.append(.init(
                code: "low-evidence-curve",
                severity: .warning,
                detail: "低可信测量下图示均衡幅度过大，本地将限制增益"
            ))
        }

        if let spatial = output.spatial,
           context.phaseRisk == "unsafe",
           spatial.stereoWidth > 1.08 || spatial.surroundLevel > 0.10 || spatial.reverbLevel > 0.12 {
            issues.append(.init(
                code: "unsafe-width",
                severity: .warning,
                detail: "相位或单声道兼容性不足，本地将收窄声场与环境量"
            ))
        }

        if let effects = output.effects {
            let unsupportedEnabled = effects.loudnessNormalizationEnabled
                || effects.compressorEnabled
                || effects.subboostEnabled
                || effects.bs2bEnabled
                || effects.crossfeedEnabled
                || effects.virtualBassEnabled
                || effects.exciterEnabled
                || effects.softclipEnabled
            if unsupportedEnabled {
                issues.append(.init(
                    code: "unsupported-stage",
                    severity: .warning,
                    detail: "模型启用了当前实时链路不接纳的兼容效果，本地将关闭"
                ))
            }
            if effects.haasEnabled && !context.haasAllowed {
                issues.append(.init(
                    code: "unsafe-haas",
                    severity: .warning,
                    detail: "当前模式或相位证据不允许 Haas 延迟，本地将关闭"
                ))
            }
            if effects.finalLimiterCeilingDB > policy.maximumLimiterCeilingDB {
                issues.append(.init(
                    code: "limiter-ceiling",
                    severity: .warning,
                    detail: "限制器上限过高，本地将下调"
                ))
            }
        }

        let requiredPreamp = estimatedRequiredPreamp(
            output: output,
            features: features
        )
        if output.preampDB > requiredPreamp + 0.25 {
            issues.append(.init(
                code: "headroom",
                severity: .warning,
                detail: "前级衰减不足以覆盖组合增益，本地将重新计算余量"
            ))
        }

        if let deviceDisplayName = context.deviceDisplayName,
           output.profileName.localizedCaseInsensitiveContains(deviceDisplayName) {
            issues.append(.init(
                code: "device-name-exposure",
                severity: .warning,
                detail: "预设名称包含设备信息，本地文案规则将替换名称"
            ))
        }

        if !context.artistReferenceAllowed,
           !output.artistStyleReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(
                code: "disabled-artist-reference",
                severity: .warning,
                detail: "歌手参考技能未启用，本地将清空模型返回的歌手参考"
            ))
        }
        if !context.vocalReferenceAllowed,
           !output.vocalCharacterReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(
                code: "disabled-vocal-reference",
                severity: .warning,
                detail: "演唱参考技能未启用，本地将清空模型返回的演唱参考"
            ))
        }

        return Review(issues: issues)
    }

    static func compileProposal(
        songID: Int,
        output: AIEqualizerModelOutput,
        features: AIEqualizerAudioFeatures,
        provider: AIWireProtocol,
        model: String,
        agentVersion: String,
        skillFingerprint: String,
        skillRevision: String,
        executionMode: AIEqualizerSkillCompliance.ExecutionMode,
        modelToolInvocationCount: Int,
        skillRuntime: MonoAudioAgentRuntimeSkillConfiguration,
        tuningIntensity: AIEqualizerTuningIntensity,
        tuningProfile: AIEqualizerTuningProfile,
        avoidingProfileNames: Set<String>,
        learningContext: AIEqualizerLearningContext?,
        deviceTuningTarget: AIEqualizerDeviceTuningTarget?
    ) throws -> AIEqualizerProposal {
        let enabledSkillIDs = Set(skillRuntime.enabledSkillIDs)
        let requiredSkillIDs = Set(skillRuntime.requiredSkillIDs)
        guard !skillFingerprint.isEmpty,
              !skillRevision.isEmpty,
              requiredSkillIDs.isSubset(of: enabledSkillIDs) else {
            let fingerprintStatus = skillFingerprint.isEmpty ? "missing" : "present"
            let revisionStatus = skillRevision.isEmpty ? "missing" : skillRevision
            AppLogger.error(
                "[MonoAudioTuningTool] Skill runtime identity or required-skill set is invalid fingerprint=\(fingerprintStatus) revision=\(revisionStatus) required=\(requiredSkillIDs.count) enabled=\(enabledSkillIDs.count)",
                step: "ai-tuning.skill-runtime-invalid"
            )
            throw AIEqualizerError.invalidResponse
        }
        switch executionMode {
        case .requiredModelTool, .appleIntelligenceLocalCompiler:
            guard modelToolInvocationCount == 1 else {
                AppLogger.error(
                    "[MonoAudioTuningTool] Required model tool invocation count is invalid mode=\(executionMode.rawValue) count=\(modelToolInvocationCount)",
                    step: "ai-tuning.tool-invocation-invalid"
                )
                throw AIEqualizerError.invalidResponse
            }
        case .modelPromptFallback:
            guard modelToolInvocationCount == 0 else {
                AppLogger.error(
                    "[MonoAudioTuningTool] Fallback execution unexpectedly reported model tool calls mode=\(executionMode.rawValue) count=\(modelToolInvocationCount)",
                    step: "ai-tuning.tool-invocation-invalid"
                )
                throw AIEqualizerError.invalidResponse
            }
        }

        let modelReview = review(
            output: output,
            features: features,
            tuningProfile: tuningProfile,
            deviceTuningTarget: deviceTuningTarget,
            skillRuntime: skillRuntime
        )
        guard modelReview.isAccepted else {
            log(modelReview, phase: "model")
            throw AIEqualizerError.invalidResponse
        }

        let compliance = AIEqualizerSkillCompliance(
            accepted: true,
            executionMode: executionMode,
            knowledgeVersion: MonoAudioTuningKnowledge.version,
            toolVersion: version,
            checkedRuleCount: MonoAudioTuningKnowledge.enforcedRuleCount,
            warningCodes: Array(Set(modelReview.issues
                .filter { $0.severity == .warning }
                .map(\.code)))
                .sorted(),
            enabledSkillIDs: skillRuntime.enabledSkillIDs,
            requiredSkillIDs: skillRuntime.requiredSkillIDs,
            modelToolInvocationCount: modelToolInvocationCount,
            localValidationApplied: true,
            validatedAt: Date()
        )
        let proposal = AIEqualizerProposal(
            songID: songID,
            output: output,
            features: features,
            provider: provider,
            model: model,
            agentVersion: agentVersion,
            skillFingerprint: skillFingerprint,
            skillRevision: skillRevision,
            skillCompliance: compliance,
            allowsArtistStyleReference: skillRuntime.enabledSkillIDs.contains(
                MonoAudioAgentBuiltInSkill.artistReference.rawValue
            ),
            allowsVocalCharacterReference: skillRuntime.enabledSkillIDs.contains(
                MonoAudioAgentBuiltInSkill.vocalReference.rawValue
            ),
            tuningIntensity: tuningIntensity,
            tuningProfile: tuningProfile,
            avoidingProfileNames: avoidingProfileNames,
            learningContext: learningContext,
            deviceTuningTarget: deviceTuningTarget
        )
        let compiledReview = reviewCompiledProposal(proposal, features: features)
        if !modelReview.issues.isEmpty {
            log(modelReview, phase: "model-corrected")
        }
        guard compiledReview.isAccepted else {
            log(compiledReview, phase: "compiled")
            throw AIEqualizerError.invalidResponse
        }
        AppLogger.debug(
            "[MonoAudioTuningTool] 方案编译通过 tool=\(version) knowledge=\(MonoAudioTuningKnowledge.version) bands=\(proposal.gains.count)",
            step: "ai-tuning.tool-compiled"
        )
        return proposal
    }

    private static func invocationContext(
        features: AIEqualizerAudioFeatures,
        tuningProfile: AIEqualizerTuningProfile,
        deviceTuningTarget: AIEqualizerDeviceTuningTarget?,
        skillRuntime: MonoAudioAgentRuntimeSkillConfiguration
    ) -> InvocationContext {
        let policy = MonoAudioTuningKnowledge.document.toolPolicy
        let durationScore = min(1, max(0, Float(
            features.sampleDuration / max(1, policy.minimumReliableSampleSeconds)
        )))
        let frameScore = min(1, max(0, Float(features.frameCount) / Float(
            max(1, policy.minimumReliableFrameCount)
        )))
        let spectrumScore = min(1, max(0, Float(features.bandEnergyDB.count) / Float(
            max(1, features.graphicEQMode.bandCount)
        )))
        let evidenceScore = durationScore * 0.42 + frameScore * 0.42 + spectrumScore * 0.16
        let evidenceClass = evidenceScore < policy.lowEvidenceScore ? "low" : "reliable"
        let phaseUnsafe = features.phaseCorrelation < policy.unsafePhaseCorrelation
            || features.monoCompatibility < policy.weakMonoCompatibility
        let phaseRisk = phaseUnsafe
            ? "unsafe"
            : (features.phaseCorrelation < 0.12 || features.monoCompatibility < 0.62 ? "caution" : "safe")
        let peakRisk = features.estimatedTruePeakDBTP >= policy.highTruePeakDBTP
            || features.clippingRatio > 0
            ? "high"
            : "normal"
        let maximumAdjacentDelta = features.graphicEQMode == .thirtyTwoBand
            ? policy.thirtyTwoBandAdjacentDeltaDB
            : policy.tenBandAdjacentDeltaDB
        let maximumParametricBands = features.graphicEQMode == .thirtyTwoBand
            ? policy.thirtyTwoBandMaximumParametricBands
            : policy.tenBandMaximumParametricBands
        let dynamicsStrategies: [String]
        if evidenceClass == "low" || peakRisk == "high" {
            dynamicsStrategies = ["none", "attenuationAndLimiterOnly"]
        } else {
            dynamicsStrategies = ["none", "dynamicEQ", "multiband"]
        }
        let haasAllowed = tuningProfile == .monoSpatialEnhancement && !phaseUnsafe

        return InvocationContext(
            tool: version,
            knowledge: MonoAudioTuningKnowledge.version,
            graphicEQMode: features.graphicEQMode.rawValue,
            expectedBandCount: features.graphicEQMode.bandCount,
            expectedFrequenciesHz: features.bandFrequenciesHz,
            maximumAdjacentDeltaDB: maximumAdjacentDelta,
            maximumParametricBands: maximumParametricBands,
            evidenceScore: evidenceScore,
            evidenceClass: evidenceClass,
            peakRisk: peakRisk,
            phaseRisk: phaseRisk,
            outputKind: features.outputKind,
            deviceBaselineAppliedLocally: deviceTuningTarget != nil,
            deviceDisplayName: deviceTuningTarget?.displayName,
            allowedPrimaryDynamicsStrategies: dynamicsStrategies,
            haasAllowed: haasAllowed,
            maximumLimiterCeilingDB: evidenceClass == "low"
                ? policy.uncertainLimiterCeilingDB
                : policy.maximumLimiterCeilingDB,
            mandatoryRules: MonoAudioTuningKnowledge.modelRules,
            enabledSkillIDs: skillRuntime.enabledSkillIDs,
            requiredSkillIDs: skillRuntime.requiredSkillIDs,
            artistReferenceAllowed: skillRuntime.enabledSkillIDs.contains(
                MonoAudioAgentBuiltInSkill.artistReference.rawValue
            ),
            vocalReferenceAllowed: skillRuntime.enabledSkillIDs.contains(
                MonoAudioAgentBuiltInSkill.vocalReference.rawValue
            )
        )
    }

    private static func reviewCompiledProposal(
        _ proposal: AIEqualizerProposal,
        features: AIEqualizerAudioFeatures
    ) -> Review {
        var issues: [Issue] = []
        if proposal.gains.count != proposal.graphicEQMode.bandCount
            || !proposal.gains.allSatisfy(\.isFinite)
            || !proposal.preampDB.isFinite
            || proposal.preampDB > 0 {
            issues.append(.init(
                code: "compiled-core",
                severity: .rejection,
                detail: "本地编译后的核心参数无效"
            ))
        }
        if proposal.professional.dynamicEQ.enabled && proposal.professional.multiband.enabled {
            issues.append(.init(
                code: "compiled-dynamics",
                severity: .rejection,
                detail: "本地编译后仍存在重复动态处理"
            ))
        }
        let policy = MonoAudioTuningKnowledge.document.toolPolicy
        let phaseUnsafe = features.phaseCorrelation < policy.unsafePhaseCorrelation
            || features.monoCompatibility < policy.weakMonoCompatibility
        if phaseUnsafe && proposal.effects.haasEnabled {
            issues.append(.init(
                code: "compiled-phase",
                severity: .rejection,
                detail: "相位风险下仍启用了 Haas 延迟"
            ))
        }
        return Review(issues: issues)
    }

    private static func maximumAdjacentDelta(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        return zip(values.dropFirst(), values).reduce(0) { maximum, pair in
            max(maximum, abs(pair.0 - pair.1))
        }
    }

    private static func estimatedRequiredPreamp(
        output: AIEqualizerModelOutput,
        features: AIEqualizerAudioFeatures
    ) -> Float {
        let graphicPeak = max(0, output.gains.max() ?? 0)
        let tonePeak = max(0, max(output.tone?.bassGain ?? 0, output.tone?.trebleGain ?? 0)) * 0.55
        let parametricPeak = output.professional?.parametricEQ.enabled == true
            ? max(0, output.professional?.parametricEQ.bands.map(\.gainDB).max() ?? 0)
            : 0
        let surround = output.spatial?.surroundLevel ?? 0
        let reverb = output.spatial?.reverbLevel ?? 0
        let width = output.spatial?.stereoWidth ?? 1
        let spatialReserve = max(0, surround) * 1.2
            + max(0, reverb)
            + max(0, width - 1) * 1.5
        let enhanceReserve = output.enhance?.estimatedPeakBoostDB ?? 0
        let dynamicsMakeup = output.effects?.compressorEnabled == true
            ? max(0, output.effects?.compressorMakeupDB ?? 0)
            : 0
        let truePeakReserve = max(0, features.estimatedTruePeakDBTP + 1)
        let clippingReserve = min(1.5, max(0, features.clippingRatio) * 6)
        return -min(
            18,
            graphicPeak + tonePeak + parametricPeak + spatialReserve
                + enhanceReserve + dynamicsMakeup + truePeakReserve
                + clippingReserve + 0.75
        )
    }

    private static func log(_ review: Review, phase: String) {
        for issue in review.issues {
            let message = "[MonoAudioTuningTool] \(phase) \(issue.code): \(issue.detail)"
            switch issue.severity {
            case .warning:
                AppLogger.warning(message, step: "ai-tuning.tool-review")
            case .rejection:
                AppLogger.error(message, step: "ai-tuning.tool-rejected")
            }
        }
    }
}
