import Foundation
import Combine
import AVFoundation
import FFmpegSwiftSDK

extension EQManager {
    // MARK: - 应用预设

    var graphicBandFrequencies: [Float] { graphicEQMode.centerFrequencies }
    var graphicBandLabels: [String] { graphicEQMode.frequencyLabels }

    func builtInPreset(familyID: String, mode: GraphicEQMode) -> EQPreset? {
        builtInPresets.first {
            !$0.isCustom && $0.familyID == familyID && $0.presetType.graphicMode == mode
        }
    }

    func matchingBuiltInPreset(_ preset: EQPreset?, mode: GraphicEQMode) -> EQPreset? {
        guard let preset else { return nil }
        guard !preset.isCustom else { return preset }
        return builtInPreset(familyID: preset.familyID, mode: mode) ?? preset
    }

    func setGraphicEQMode(_ mode: GraphicEQMode) {
        guard mode != graphicEQMode else { return }
        if isAIManagedPresetActive {
            restoreProcessingBeforeAI(reason: "manual-band-mode")
        }

        if graphicEQMode == .tenBand {
            tenBandCustomGains = GraphicEQMode.tenBand.normalizedGains(customGains)
        } else {
            thirtyTwoBandCustomGains = GraphicEQMode.thirtyTwoBand.normalizedGains(customGains)
        }

        isRestoring = true
        graphicEQMode = mode
        customGains = mode == .tenBand ? tenBandCustomGains : thirtyTwoBandCustomGains
        currentPreset = matchingBuiltInPreset(currentPreset, mode: mode)
        isRestoring = false

        if isEnabled {
            if let preset = currentPreset, preset.id != "custom" {
                applyPresetCurve(preset)
            } else {
                applyCustomGains()
            }
            applyProfessionalConfiguration()
            updateSafetyLimiter()
        } else {
            PlayerManager.shared.equalizer.setGraphicMode(mode, gainsDB: customGains)
        }
        saveState()
    }

    func applyPresetCurve(_ preset: EQPreset, mode: GraphicEQMode? = nil) {
        let targetMode = mode ?? graphicEQMode
        PlayerManager.shared.equalizer.setGraphicMode(
            targetMode,
            gainsDB: preset.gains(in: targetMode)
        )
    }
    
    func applyPreset(_ preset: EQPreset) {
        if isAIManagedPresetActive, !preset.id.hasPrefix("ai_") {
            restoreProcessingBeforeAI(reason: "manual-preset")
        }
        let resolvedPreset = matchingBuiltInPreset(preset, mode: graphicEQMode) ?? preset
        currentPreset = resolvedPreset
        if !isEnabled {
            isEnabled = true
        }
        if !resolvedPreset.isCustom {
            applyBuiltInProcessingProfile(resolvedPreset)
        }
        updateSafetyLimiter()
        saveAudioEffectsState()
    }
    
    func applyFlat() {
        if isAIManagedPresetActive {
            restoreProcessingBeforeAI(reason: "manual-flat")
        }
        currentPreset = builtInPreset(familyID: "flat", mode: graphicEQMode)
        if currentPreset == nil {
            PlayerManager.shared.equalizer.setGraphicMode(
                graphicEQMode,
                gainsDB: Array(repeating: 0, count: graphicEQMode.bandCount)
            )
            applyProfessionalConfiguration()
        }
        if let currentPreset {
            applyBuiltInProcessingProfile(currentPreset)
        }
        updateSafetyLimiter()
        saveAudioEffectsState()
    }

    func applyBuiltInProcessingProfile(_ preset: EQPreset) {
        let player = PlayerManager.shared
        let profile = preset.processingProfile
        let wasRestoring = isRestoring
        isRestoring = true
        monoEffectTuning = profile.effects
        isRestoring = wasRestoring
        player.audioEffects.applyMonoTuning(
            profile.effects,
            bassGain: profile.bassGain,
            trebleGain: profile.trebleGain,
            surroundLevel: preset.surroundLevel,
            reverbLevel: preset.reverbLevel,
            stereoWidth: preset.stereoWidth
        )
    }

    /// 切换歌曲时撤销上一首 AI 方案，恢复用户在开启 AI 调音前的处理链。
    func prepareForAIAnalysis(songIdentifier: String) {
        restoreProcessingBeforeAI(reason: "track-changed")
        beginSongAnalysis(identifier: songIdentifier)
        configureSmartAnalysis()
    }

    /// 关闭 AI 或切换歌曲时恢复 AI 覆盖前的完整用户处理链。
    func restoreProcessingBeforeAI(reason: String) {
        guard preAIProcessingSnapshot != nil || isAIManagedPresetActive else { return }
        stopLoudnessMatchedReferenceAudition()

        let previousPreset = currentPreset?.name ?? "none"
        let snapshot = preAIProcessingSnapshot ?? neutralAIProcessingSnapshot()
        isRestoring = true
        isEnabled = snapshot.isEnabled
        let restoredMode = snapshot.graphicEQMode
            ?? (snapshot.customGains.count == GraphicEQMode.thirtyTwoBand.bandCount ? .thirtyTwoBand : .tenBand)
        graphicEQMode = restoredMode
        currentPreset = matchingBuiltInPreset(snapshot.currentPreset, mode: restoredMode)
        tenBandCustomGains = GraphicEQMode.tenBand.normalizedGains(
            snapshot.tenBandCustomGains ?? (restoredMode == .tenBand ? snapshot.customGains : [])
        )
        thirtyTwoBandCustomGains = GraphicEQMode.thirtyTwoBand.normalizedGains(
            snapshot.thirtyTwoBandCustomGains ?? (restoredMode == .thirtyTwoBand ? snapshot.customGains : [])
        )
        customGains = restoredMode == .tenBand ? tenBandCustomGains : thirtyTwoBandCustomGains
        customPresetPreampDB = snapshot.customPresetPreampDB
        professionalProcessingIntensity = snapshot.professionalProcessingIntensity
        isLoudnessMatchingEnabled = snapshot.isLoudnessMatchingEnabled
        isOutputCalibrationEnabled = snapshot.isOutputCalibrationEnabled
        isSmartSongCompensationEnabled = snapshot.isSmartSongCompensationEnabled
        isDynamicEQEnabled = snapshot.isDynamicEQEnabled
        dynamicEQBands = snapshot.dynamicEQBands
        isMultibandDynamicsEnabled = snapshot.isMultibandDynamicsEnabled
        multibandConfiguration = snapshot.multibandConfiguration
        isParametricEQEnabled = snapshot.isParametricEQEnabled
        parametricBands = snapshot.parametricBands
        monoEffectTuning = snapshot.monoEffectTuning ?? .neutral
        monoEnhanceConfiguration = snapshot.monoEnhanceConfiguration ?? .neutral
        adaptiveGains = Array(repeating: 0, count: 10)
        committedAdaptiveGains = adaptiveGains
        lastSmartDSPCommit = Date()
        isRestoring = false

        let player = PlayerManager.shared
        player.equalizer.reset()
        player.equalizer.setProcessingEnabled(snapshot.isEnabled)
        if snapshot.isEnabled {
            if let preset = snapshot.currentPreset, preset.id != "custom" {
                applyPresetCurve(preset, mode: restoredMode)
            } else {
                player.equalizer.setGraphicMode(restoredMode, gainsDB: customGains)
            }
        } else {
            player.equalizer.setGraphicMode(restoredMode, gainsDB: customGains)
        }
        player.audioEffects.applyMonoTuning(
            effectiveMonoEffectTuningForCurrentOutput(),
            bassGain: snapshot.bassGain,
            trebleGain: snapshot.trebleGain,
            surroundLevel: snapshot.surroundLevel,
            reverbLevel: snapshot.reverbLevel,
            stereoWidth: snapshot.stereoWidth
        )

        applyProfessionalConfiguration()
        applyMonoEffectTuning()
        configureSmartAnalysis()
        updateSafetyLimiter()
        preAIProcessingSnapshot = nil
        UserDefaults.standard.removeObject(forKey: Self.aiProcessingSnapshotKey)
        saveState()
        saveProfessionalState()
        saveAudioEffectsState()

        AppLogger.info(
            "[EQManager] Restored processing before AI preset=\(previousPreset) reason=\(reason)",
            step: "ai-tuning.restore"
        )
    }

    /// 将 AI 生成的完整 Mono 处理方案一次性写入引擎，避免逐项触发重复重建 DSP 链。
    func applyAIConfiguration(
        _ proposal: AIEqualizerProposal,
        spatialOverride: AIEqualizerSpatialConfiguration? = nil
    ) {
        stopLoudnessMatchedReferenceAudition()
        captureProcessingBeforeAIIfNeeded()

        let professional = proposal.professional
        let requestedSpatial = spatialOverride ?? proposal.spatial
        let isSpatialProfile = proposal.resolvedTuningProfile == .monoSpatialEnhancement
        let spatialMinimum: (surround: Float, reverb: Float, width: Float)
        let spatialMaximum: (surround: Float, reverb: Float, width: Float)
        // 空间档的下限要保证与标准档拉开可闻差距：标准档上限（约 0.06/0.03/1.05）
        // 与这里的下限之间需要留出足够的侧声道与湿度间隔，否则两档听感趋同。
        switch (isSpatialProfile, currentOutputKind) {
        // 外放时宽度感知弱，主要靠混响湿度与舞台展宽制造空间感。
        case (true, .builtInSpeaker):
            spatialMinimum = (0.30, 0.40, 1.16)
            spatialMaximum = (0.48, 0.64, 1.30)
        case (true, .bluetooth):
            spatialMinimum = (0.38, 0.34, 1.22)
            spatialMaximum = (0.62, 0.58, 1.42)
        case (true, .wired), (true, .usb):
            spatialMinimum = (0.42, 0.38, 1.26)
            spatialMaximum = (0.68, 0.62, 1.48)
        case (true, .car):
            spatialMinimum = (0.30, 0.32, 1.16)
            spatialMaximum = (0.50, 0.54, 1.30)
        case (true, .airPlay):
            spatialMinimum = (0.30, 0.32, 1.18)
            spatialMaximum = (0.52, 0.56, 1.34)
        case (true, .other):
            spatialMinimum = (0.34, 0.34, 1.20)
            spatialMaximum = (0.58, 0.58, 1.38)
        case (false, .builtInSpeaker):
            spatialMinimum = (0, 0, 1)
            spatialMaximum = (0.03, 0.012, 1.025)
        case (false, .wired), (false, .usb):
            spatialMinimum = (0, 0, 1)
            spatialMaximum = (0.06, 0.025, 1.05)
        case (false, .bluetooth):
            spatialMinimum = (0, 0, 1)
            spatialMaximum = (0.055, 0.022, 1.045)
        case (false, .car):
            spatialMinimum = (0, 0, 1)
            spatialMaximum = (0.04, 0.018, 1.035)
        case (false, .airPlay), (false, .other):
            spatialMinimum = (0, 0, 1)
            spatialMaximum = (0.05, 0.020, 1.04)
        }
        let resolvedSpatial = AIEqualizerSpatialConfiguration(
            surroundLevel: min(
                spatialMaximum.surround,
                max(spatialMinimum.surround, requestedSpatial.surroundLevel)
            ),
            reverbLevel: min(
                spatialMaximum.reverb,
                max(spatialMinimum.reverb, requestedSpatial.reverbLevel)
            ),
            stereoWidth: min(
                spatialMaximum.width,
                max(spatialMinimum.width, requestedSpatial.stereoWidth)
            )
        )
        let dynamicBands = professional.dynamicEQ.bands.map {
            DynamicEQBand(
                frequency: $0.frequency,
                q: $0.q,
                thresholdDB: $0.thresholdDB,
                ratio: $0.ratio,
                maxReductionDB: $0.maxReductionDB,
                attackMS: $0.attackMS,
                releaseMS: $0.releaseMS
            )
        }
        let parametricBands = professional.parametricEQ.bands.compactMap { band -> ParametricEQBand? in
            guard let type = ParametricEQFilterType(rawValue: band.type) else { return nil }
            return ParametricEQBand(
                type: type,
                frequency: band.frequency,
                gainDB: band.gainDB,
                q: band.q
            )
        }
        let multiband = professional.multiband
        let multibandConfiguration = MultibandDynamicsConfiguration(
            isEnabled: multiband.enabled,
            lowCrossoverHz: multiband.lowCrossoverHz,
            highCrossoverHz: multiband.highCrossoverHz,
            thresholdsDB: multiband.thresholdsDB,
            ratios: multiband.ratios,
            maxReductionDB: multiband.maxReductionDB,
            attackMS: multiband.attackMS,
            releaseMS: multiband.releaseMS
        )
        var resolvedEnhance = proposal.enhance
        // Applying an AI proposal always enables the safe native tuning core.
        // Providers may reduce individual values, but cannot silently turn the
        // entire result into bypass while the UI reports “已应用”.
        resolvedEnhance.isEnabled = true
        if resolvedEnhance.isEnabled {
            let intensityScale: Float
            switch proposal.tuningIntensity ?? .smart {
            case .gentle: intensityScale = 0.72
            case .standard: intensityScale = 0.88
            case .smart: intensityScale = 1
            case .strong: intensityScale = 1.14
            }
            let tonalFloor: (
                attack: Float,
                sustain: Float,
                vocal: Float,
                air: Float,
                deEss: Float,
                lowFocus: Float,
                microDynamics: Float,
                lowLevel: Float
            )
            switch currentOutputKind {
            case .builtInSpeaker:
                tonalFloor = (0.36, 0.22, 0.30, 0.18, 0.22, 0.42, 0.28, 0.24)
            case .bluetooth:
                tonalFloor = (0.32, 0.20, 0.26, 0.20, 0.25, 0.34, 0.26, 0.18)
            case .wired, .usb:
                tonalFloor = (0.34, 0.21, 0.25, 0.21, 0.25, 0.35, 0.27, 0.18)
            case .car, .airPlay, .other:
                tonalFloor = (0.31, 0.20, 0.27, 0.18, 0.23, 0.37, 0.25, 0.20)
            }
            // 标准与空间方案都要先完成可闻的音色、瞬态和动态处理；
            // 空间方案只是在同一调音底座上额外展开声场，不能靠削弱标准方案制造差异。
            resolvedEnhance.transientAttack = max(
                tonalFloor.attack * intensityScale,
                resolvedEnhance.transientAttack
            )
            resolvedEnhance.transientSustain = max(
                tonalFloor.sustain * intensityScale,
                resolvedEnhance.transientSustain
            )
            resolvedEnhance.vocalFocus = max(
                tonalFloor.vocal * intensityScale,
                resolvedEnhance.vocalFocus
            )
            resolvedEnhance.airAmount = max(
                tonalFloor.air * intensityScale,
                resolvedEnhance.airAmount
            )
            resolvedEnhance.deEssAmount = max(
                tonalFloor.deEss * intensityScale,
                resolvedEnhance.deEssAmount
            )
            resolvedEnhance.lowFrequencyFocus = max(
                tonalFloor.lowFocus * intensityScale,
                resolvedEnhance.lowFrequencyFocus
            )
            resolvedEnhance.microDynamics = max(
                tonalFloor.microDynamics * intensityScale,
                resolvedEnhance.microDynamics
            )
            resolvedEnhance.lowLevelCompensation = max(
                tonalFloor.lowLevel * intensityScale,
                resolvedEnhance.lowLevelCompensation
            )
            if isSpatialProfile {
                let minimumStageWidth: Float
                switch currentOutputKind {
                case .builtInSpeaker: minimumStageWidth = 0.76
                case .bluetooth, .wired, .usb: minimumStageWidth = 0.78
                case .car, .airPlay, .other: minimumStageWidth = 0.72
                }
                resolvedEnhance.stageWidth = max(minimumStageWidth, resolvedEnhance.stageWidth)
                resolvedEnhance.vocalFocus = max(0.16, resolvedEnhance.vocalFocus)
            } else {
                // 标准方案的调音保持完整，但不主动扩张原始声场。
                resolvedEnhance.stageWidth = min(0.08, resolvedEnhance.stageWidth)
            }
            let outputVolume = AVAudioSession.sharedInstance().outputVolume
            let quietness = min(1, max(0, (0.62 - outputVolume) / 0.62))
            let deviceMaximum: Float
            switch currentOutputKind {
            case .builtInSpeaker: deviceMaximum = 0.34
            case .bluetooth, .wired, .usb: deviceMaximum = 0.42
            case .car, .airPlay, .other: deviceMaximum = 0.38
            }
            let highVolumeFloor = resolvedEnhance.lowLevelCompensation * 0.35
            resolvedEnhance.lowLevelCompensation = min(
                deviceMaximum,
                highVolumeFloor + (deviceMaximum - highVolumeFloor) * quietness
            )
        }
        let generatedPreset = EQPreset(
            id: "ai_\(proposal.songID)",
            name: proposal.profileName,
            category: .custom,
            description: proposal.profileSpecificSummary,
            gains: proposal.gains,
            isCustom: true,
            presetType: proposal.graphicEQMode == .tenBand ? .standard10 : .graphic32,
            preampDB: proposal.preampDB
        )

        isRestoring = true
        graphicEQMode = proposal.graphicEQMode
        customGains = proposal.gains
        if proposal.graphicEQMode == .tenBand {
            tenBandCustomGains = proposal.gains
        } else {
            thirtyTwoBandCustomGains = proposal.gains
        }
        customPresetPreampDB = proposal.preampDB
        currentPreset = generatedPreset
        professionalProcessingIntensity = professional.processingIntensity
        isOutputCalibrationEnabled = proposal.calibration.outputCalibrationEnabled
        isLoudnessMatchingEnabled = proposal.calibration.loudnessMatchingEnabled
        isSmartSongCompensationEnabled = proposal.calibration.smartSongCompensationEnabled
        isDynamicEQEnabled = professional.dynamicEQ.enabled
        dynamicEQBands = dynamicBands.isEmpty ? DynamicEQBand.monoDefaults : dynamicBands
        isMultibandDynamicsEnabled = multiband.enabled
        self.multibandConfiguration = multibandConfiguration
        isParametricEQEnabled = professional.parametricEQ.enabled && !parametricBands.isEmpty
        self.parametricBands = parametricBands
        monoEffectTuning = proposal.effects
        monoEnhanceConfiguration = resolvedEnhance
        isEnabled = true
        isRestoring = false

        let player = PlayerManager.shared
        player.equalizer.setProcessingEnabled(true)
        applyPresetCurve(generatedPreset, mode: proposal.graphicEQMode)
        let effectiveEffects = effectiveMonoEffectTuningForCurrentOutput()
        player.audioEffects.applyMonoTuning(
            effectiveEffects,
            bassGain: proposal.tone.bassGain,
            trebleGain: proposal.tone.trebleGain,
            surroundLevel: resolvedSpatial.surroundLevel,
            reverbLevel: resolvedSpatial.reverbLevel,
            stereoWidth: resolvedSpatial.stereoWidth
        )
        player.audioRepair.configureOutputSafety(
            limiterEnabled: effectiveEffects.finalLimiterEnabled,
            ceilingDB: effectiveEffects.finalLimiterCeilingDB,
            transitionProtectionEnabled: false,
            outputGainDB: player.audioRepair.outputGainDB,
            perceptualMakeupDB: player.audioRepair.perceptualMakeupDB
        )
        isSafetyLimiterActive = effectiveEffects.finalLimiterEnabled

        beginSongAnalysis(identifier: player.currentSong.map { "\($0.musicSource.rawValue):\($0.id)" })
        applyProfessionalConfiguration()
        configureSmartAnalysis()
        updateSafetyLimiter()
        let committedGains = player.equalizer.graphicGains
        let committedEnhance = player.equalizer.monoEnhanceConfiguration
        let maximumCurveDelta = zip(
            proposal.graphicEQMode.normalizedGains(proposal.gains),
            committedGains
        ).map { abs($0 - $1) }.max() ?? .infinity
        let committedPresetID = currentPreset?.id ?? "none"
        let curveDeltaText = String(format: "%.4f", maximumCurveDelta)
        let attackText = String(format: "%.3f", committedEnhance.transientAttack)
        let vocalText = String(format: "%.3f", committedEnhance.vocalFocus)
        let airText = String(format: "%.3f", committedEnhance.airAmount)
        let stageText = String(format: "%.3f", committedEnhance.stageWidth)
        let surroundText = String(format: "%.3f", player.audioEffects.surroundLevel)
        let reverbText = String(format: "%.3f", player.audioEffects.reverbLevel)
        let widthText = String(format: "%.3f", player.audioEffects.stereoWidth)
        AppLogger.info(
            "[EQManager] AI DSP commit enabled=\(player.equalizer.isProcessingEnabled) preset=\(committedPresetID) mode=\(graphicEQMode.rawValue) curveDelta=\(curveDeltaText) enhance=\(committedEnhance.hasAudibleProcessing) attack=\(attackText) vocal=\(vocalText) air=\(airText) stage=\(stageText) surround=\(surroundText) reverb=\(reverbText) width=\(widthText)",
            step: "ai-tuning.dsp-commit"
        )
        saveState()
        saveProfessionalState()
        saveAudioEffectsState()
    }
    
}
