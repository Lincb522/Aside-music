import Foundation
import FFmpegSwiftSDK

private struct AIEqualizerSamplingDiagnostics: Sendable {
    let callbackFrames: Int
    let acceptedFrames: Int
    let invalidShapeFrames: Int
    let invalidValueFrames: Int
    let silentFrames: Int
    let emptySpectrumFrames: Int
    let lastBinCount: Int
    let lastSampleRate: Double
    let lastRMS: Float

    var logText: String {
        String(
            format: "callbacks=%d accepted=%d invalidShape=%d invalidValue=%d silent=%d emptySpectrum=%d lastBins=%d sampleRate=%.0f lastRMS=%.6f",
            callbackFrames,
            acceptedFrames,
            invalidShapeFrames,
            invalidValueFrames,
            silentFrames,
            emptySpectrumFrames,
            lastBinCount,
            lastSampleRate,
            lastRMS
        )
    }
}

private actor AIEqualizerSpectrumAccumulator {
    private static let centers: [Float] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]

    private var bandDBFrames = Array(repeating: [Float](), count: 10)
    private var centroidFrames: [Float] = []
    private var rolloffFrames: [Float] = []
    private var flatnessFrames: [Float] = []
    private var rmsDBFrames: [Float] = []
    private var latestSampleRate: Double = 44_100
    private var callbackFrames = 0
    private var invalidShapeFrames = 0
    private var invalidValueFrames = 0
    private var silentFrames = 0
    private var emptySpectrumFrames = 0
    private var lastBinCount = 0
    private var lastRMS: Float = 0
    private(set) var frameCount = 0

    func ingest(magnitudes: [Float], sampleRate: Double, rms: Float) {
        callbackFrames += 1
        lastBinCount = magnitudes.count
        lastRMS = rms
        guard magnitudes.count > 16 else {
            invalidShapeFrames += 1
            return
        }
        guard sampleRate.isFinite, sampleRate > 0, rms.isFinite else {
            invalidValueFrames += 1
            return
        }
        latestSampleRate = sampleRate

        let binHz = Float(sampleRate) / Float(magnitudes.count * 2)
        var bandPower = Array(repeating: Float(0), count: 10)
        var bandBins = Array(repeating: 0, count: 10)
        var totalPower: Float = 0
        var weightedPower: Float = 0
        var powers: [Float] = []
        powers.reserveCapacity(magnitudes.count)

        for (index, magnitude) in magnitudes.enumerated() {
            guard magnitude.isFinite else { continue }
            let frequency = Float(index) * binHz
            guard frequency >= 20, frequency <= 20_000 else { continue }
            let power = max(magnitude * magnitude, 1e-20)
            totalPower += power
            weightedPower += frequency * power
            powers.append(power)

            let band = Self.nearestBand(for: frequency)
            bandPower[band] += power
            bandBins[band] += 1
        }

        let rmsDB = 20 * log10f(max(rms, 1e-8))
        guard rmsDB > -72 else {
            silentFrames += 1
            return
        }
        guard totalPower.isFinite, totalPower > 1e-18, !powers.isEmpty else {
            emptySpectrumFrames += 1
            return
        }
        var frameBandDB = Array(repeating: Float(-80), count: 10)
        for index in 0..<10 where bandBins[index] > 0 {
            let meanPower = bandPower[index] / Float(bandBins[index])
            frameBandDB[index] = 10 * log10f(max(meanPower, 1e-20))
        }
        let peakBand = frameBandDB.max() ?? 0
        for index in 0..<10 {
            bandDBFrames[index].append(max(-60, frameBandDB[index] - peakBand))
        }

        centroidFrames.append(weightedPower / totalPower)
        rolloffFrames.append(Self.rolloffFrequency(powers: powers, binHz: binHz, ratio: 0.85))

        let arithmeticMean = powers.reduce(0, +) / Float(powers.count)
        let logMean = powers.reduce(Float(0)) { $0 + logf(max($1, 1e-20)) } / Float(powers.count)
        flatnessFrames.append(arithmeticMean > 0 ? min(1, expf(logMean) / arithmeticMean) : 0)
        rmsDBFrames.append(rmsDB)
        frameCount += 1
    }

    func diagnostics() -> AIEqualizerSamplingDiagnostics {
        AIEqualizerSamplingDiagnostics(
            callbackFrames: callbackFrames,
            acceptedFrames: frameCount,
            invalidShapeFrames: invalidShapeFrames,
            invalidValueFrames: invalidValueFrames,
            silentFrames: silentFrames,
            emptySpectrumFrames: emptySpectrumFrames,
            lastBinCount: lastBinCount,
            lastSampleRate: latestSampleRate,
            lastRMS: lastRMS
        )
    }

    func makeFeatures(
        songID: Int,
        title: String,
        artist: String,
        source: String,
        outputDevice: String,
        outputKind: String,
        currentBassGain: Float,
        currentTrebleGain: Float,
        currentSurroundLevel: Float,
        currentReverbLevel: Float,
        currentStereoWidth: Float,
        professionalProcessingIntensity: Float,
        outputCalibrationEnabled: Bool,
        loudnessMatchingEnabled: Bool,
        smartSongCompensationEnabled: Bool,
        dynamicEQEnabled: Bool,
        multibandDynamicsEnabled: Bool,
        parametricEQEnabled: Bool,
        duration: Double
    ) throws -> AIEqualizerAudioFeatures {
        guard frameCount >= 48 else { throw AIEqualizerError.sampleUnavailable }

        let bands = bandDBFrames.map { min(0, max(-60, Self.trimmedMean($0, trimFraction: 0.12))) }
        let sortedRMS = rmsDBFrames.sorted()
        let p10 = Self.percentile(sortedRMS, 0.10)
        let p90 = Self.percentile(sortedRMS, 0.90)
        let rmsMean = Self.trimmedMean(rmsDBFrames, trimFraction: 0.10)

        return AIEqualizerAudioFeatures(
            songID: songID,
            title: title,
            artist: artist,
            source: source,
            outputDevice: outputDevice,
            outputKind: outputKind,
            sampleDuration: duration,
            sampleRate: latestSampleRate,
            frameCount: frameCount,
            bandEnergyDB: bands,
            spectralCentroidHz: Self.trimmedMean(centroidFrames, trimFraction: 0.12),
            spectralRolloffHz: Self.trimmedMean(rolloffFrames, trimFraction: 0.12),
            rmsDBFS: rmsMean,
            dynamicSpreadDB: max(0, p90 - p10),
            spectralFlatness: min(1, max(0, Self.trimmedMean(flatnessFrames, trimFraction: 0.12))),
            currentBassGain: currentBassGain,
            currentTrebleGain: currentTrebleGain,
            currentSurroundLevel: currentSurroundLevel,
            currentReverbLevel: currentReverbLevel,
            currentStereoWidth: currentStereoWidth,
            professionalProcessingIntensity: professionalProcessingIntensity,
            outputCalibrationEnabled: outputCalibrationEnabled,
            loudnessMatchingEnabled: loudnessMatchingEnabled,
            smartSongCompensationEnabled: smartSongCompensationEnabled,
            dynamicEQEnabled: dynamicEQEnabled,
            multibandDynamicsEnabled: multibandDynamicsEnabled,
            parametricEQEnabled: parametricEQEnabled
        )
    }

    private static func nearestBand(for frequency: Float) -> Int {
        var bestIndex = 0
        var bestDistance = Float.greatestFiniteMagnitude
        for (index, center) in centers.enumerated() {
            let distance = abs(log2f(max(frequency, 1) / center))
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    private static func rolloffFrequency(powers: [Float], binHz: Float, ratio: Float) -> Float {
        let threshold = powers.reduce(0, +) * ratio
        var accumulated: Float = 0
        for (index, power) in powers.enumerated() {
            accumulated += power
            if accumulated >= threshold {
                return Float(index) * binHz + 20
            }
        }
        return Float(powers.count) * binHz
    }

    private static func percentile(_ values: [Float], _ percentile: Float) -> Float {
        guard !values.isEmpty else { return -80 }
        let position = Int((Float(values.count - 1) * percentile).rounded())
        return values[min(values.count - 1, max(0, position))]
    }

    private static func trimmedMean(_ values: [Float], trimFraction: Float) -> Float {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let trimCount = min(
            max(0, Int(Float(sorted.count) * trimFraction)),
            max(0, (sorted.count - 1) / 2)
        )
        let retained = sorted[trimCount..<(sorted.count - trimCount)]
        return retained.reduce(0, +) / Float(max(1, retained.count))
    }
}

@MainActor
final class AIEqualizerFeatureSampler {
    private let minimumValidFrames = 48

    func sample(
        song: Song,
        duration requestedDuration: TimeInterval,
        progress: @escaping @MainActor (Double, AIEqualizerSamplingStage) -> Void
    ) async throws -> AIEqualizerAudioFeatures {
        let samplingDuration = min(90, max(6, requestedDuration))
        let timeout = samplingDuration + 4
        let player = PlayerManager.shared
        guard isCurrentSong(song, in: player) else { throw AIEqualizerError.noSong }
        guard player.isPlaying else { throw AIEqualizerError.playbackRequired }

        let analyzer = player.analysisSpectrumAnalyzer
        let accumulator = AIEqualizerSpectrumAccumulator()
        let startedAt = Date()
        let targetText = String(format: "%.1f", samplingDuration)
        let startPositionText = String(format: "%.1f", player.currentTime)
        let startDurationText = String(format: "%.1f", player.duration)
        let analyzerRateText = String(format: "%.0f", analyzer.sampleRate)
        AppLogger.info(
            "[AIEqualizerSampler] Start source=\(song.musicSource.rawValue) songID=\(song.id) target=\(targetText)s playerState=\(String(describing: player.streamPlayer.state)) appPlaying=\(player.isPlaying) loading=\(player.isLoading) position=\(startPositionText)/\(startDurationText) analyzerEnabled=\(analyzer.isEnabled) calibrationEnabled=\(analyzer.isCalibrationEnabled) sampleRate=\(analyzerRateText)",
            step: "sampling.start"
        )
        let token = analyzer.addAnalysisObserver { magnitudes, sampleRate, rms in
            Task {
                await accumulator.ingest(magnitudes: magnitudes, sampleRate: sampleRate, rms: rms)
            }
        }
        AppLogger.debug(
            "[AIEqualizerSampler] Observer registered token=\(token.uuidString)",
            step: "sampling.observer"
        )
        defer {
            analyzer.removeAnalysisObserver(token)
            AppLogger.debug(
                "[AIEqualizerSampler] Observer removed token=\(token.uuidString)",
                step: "sampling.observer"
            )
        }

        var lastLoggedSecond = -1
        var didLogFirstCallback = false
        var didLogMissingCallbackWarning = false
        var didLogRejectedFrameWarning = false
        var lastLoggedStage: AIEqualizerSamplingStage?

        while Date().timeIntervalSince(startedAt) < timeout {
            try Task.checkCancellation()
            guard isCurrentSong(song, in: player) else {
                let actualIdentifier = player.currentSong.map {
                    "\($0.musicSource.rawValue):\($0.id)"
                } ?? "none"
                AppLogger.warning(
                    "[AIEqualizerSampler] Song changed during sampling expected=\(song.musicSource.rawValue):\(song.id) actual=\(actualIdentifier)",
                    step: "sampling.interrupted"
                )
                throw AIEqualizerError.noSong
            }
            let snapshot = await accumulator.diagnostics()
            let count = snapshot.acceptedFrames
            let elapsed = Date().timeIntervalSince(startedAt)
            let timeProgress = min(1, elapsed / samplingDuration)
            let frameReadiness = min(1, Double(count) / Double(minimumValidFrames))
            let stage: AIEqualizerSamplingStage
            if snapshot.callbackFrames == 0 {
                stage = .waitingForAudio
            } else if timeProgress < 0.38 {
                stage = .collectingSpectrum
            } else if timeProgress < 0.7 {
                stage = .measuringDynamics
            } else if timeProgress < 0.94 {
                stage = .organizingFeatures
            } else {
                stage = .finalizing
            }
            progress(min(0.98, timeProgress * 0.9 + frameReadiness * 0.1), stage)
            if stage != lastLoggedStage {
                lastLoggedStage = stage
                AppLogger.info(
                    "[AIEqualizerSampler] Stage changed stage=\(stage.rawValue) elapsed=\(String(format: "%.1f", elapsed))s accepted=\(snapshot.acceptedFrames)",
                    step: "sampling.stage"
                )
            }
            if !didLogFirstCallback, snapshot.callbackFrames > 0 {
                didLogFirstCallback = true
                let firstCallbackText = String(format: "%.2f", elapsed)
                AppLogger.info(
                    "[AIEqualizerSampler] First spectrum callback after \(firstCallbackText)s; \(snapshot.logText)",
                    step: "sampling.first-frame"
                )
            }
            if !didLogMissingCallbackWarning, elapsed >= 3, snapshot.callbackFrames == 0 {
                didLogMissingCallbackWarning = true
                AppLogger.warning(
                    "[AIEqualizerSampler] No spectrum callback after 3s playerState=\(String(describing: player.streamPlayer.state)) appPlaying=\(player.isPlaying) loading=\(player.isLoading) analyzerEnabled=\(analyzer.isEnabled) calibrationEnabled=\(analyzer.isCalibrationEnabled)",
                    step: "sampling.no-callback"
                )
            }
            if !didLogRejectedFrameWarning,
               elapsed >= 5,
               snapshot.callbackFrames > 0,
               snapshot.acceptedFrames == 0 {
                didLogRejectedFrameWarning = true
                AppLogger.warning(
                    "[AIEqualizerSampler] Spectrum callbacks received but all frames were rejected; \(snapshot.logText)",
                    step: "sampling.frames-rejected"
                )
            }
            let elapsedSecond = Int(elapsed)
            if elapsedSecond > 0, elapsedSecond % 5 == 0, elapsedSecond != lastLoggedSecond {
                lastLoggedSecond = elapsedSecond
                AppLogger.debug(
                    "[AIEqualizerSampler] Progress elapsed=\(elapsedSecond)s target=\(targetText)s playerState=\(String(describing: player.streamPlayer.state)) appPlaying=\(player.isPlaying) loading=\(player.isLoading); \(snapshot.logText)",
                    step: "sampling.progress"
                )
            }
            if count >= minimumValidFrames, elapsed >= samplingDuration { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        // Let observer tasks already enqueued by the audio callback reach the actor.
        await Task.yield()
        let finalDiagnostics = await accumulator.diagnostics()
        guard finalDiagnostics.acceptedFrames >= minimumValidFrames else {
            let elapsedText = String(format: "%.1f", Date().timeIntervalSince(startedAt))
            AppLogger.error(
                "[AIEqualizerSampler] No usable audio after \(elapsedText)s playerState=\(String(describing: player.streamPlayer.state)) appPlaying=\(player.isPlaying) loading=\(player.isLoading) analyzerEnabled=\(analyzer.isEnabled) calibrationEnabled=\(analyzer.isCalibrationEnabled); \(finalDiagnostics.logText)",
                step: "sampling.failed"
            )
            throw AIEqualizerError.sampleUnavailable
        }

        let outputName = EQManager.shared.currentOutputName.isEmpty
            ? EQManager.shared.currentOutputKind.title
            : EQManager.shared.currentOutputName
        let manager = EQManager.shared
        let effects = player.audioEffects
        let features = try await accumulator.makeFeatures(
            songID: song.id,
            title: song.name,
            artist: song.artistName,
            source: song.musicSource.rawValue,
            outputDevice: outputName,
            outputKind: manager.currentOutputKind.rawValue,
            currentBassGain: effects.bassGain,
            currentTrebleGain: effects.trebleGain,
            currentSurroundLevel: effects.surroundLevel,
            currentReverbLevel: effects.reverbLevel,
            currentStereoWidth: effects.stereoWidth,
            professionalProcessingIntensity: manager.professionalProcessingIntensity,
            outputCalibrationEnabled: manager.isOutputCalibrationEnabled,
            loudnessMatchingEnabled: manager.isLoudnessMatchingEnabled,
            smartSongCompensationEnabled: manager.isSmartSongCompensationEnabled,
            dynamicEQEnabled: manager.isDynamicEQEnabled,
            multibandDynamicsEnabled: manager.isMultibandDynamicsEnabled,
            parametricEQEnabled: manager.isParametricEQEnabled,
            duration: Date().timeIntervalSince(startedAt)
        )
        let measuredDurationText = String(format: "%.1f", features.sampleDuration)
        let measuredRateText = String(format: "%.0f", features.sampleRate)
        let measuredRMSText = String(format: "%.2f", features.rmsDBFS)
        AppLogger.success(
            "[AIEqualizerSampler] Completed duration=\(measuredDurationText)s frames=\(features.frameCount) sampleRate=\(measuredRateText) rms=\(measuredRMSText)dBFS",
            step: "sampling.completed"
        )
        progress(1, .finalizing)
        return features
    }

    private func isCurrentSong(_ song: Song, in player: PlayerManager) -> Bool {
        guard let current = player.currentSong else { return false }
        return current.id == song.id && current.musicSource == song.musicSource
    }
}
