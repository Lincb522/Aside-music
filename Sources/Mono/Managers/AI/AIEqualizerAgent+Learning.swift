import Foundation
import CryptoKit
@preconcurrency import Combine
import FFmpegSwiftSDK
import UIKit

extension AIEqualizerAgent {
    func beginLearningSession(for proposal: AIEqualizerProposal) {
        guard adaptiveLearningEnabled,
              let song = PlayerManager.shared.currentSong,
              song.id == proposal.songID else {
            activeLearningSession = nil
            currentLearningFeedback = nil
            return
        }
        let previousFeedback = learningStore.feedback(for: proposal.id)
        currentLearningFeedback = previousFeedback
        activeLearningSession = AIEqualizerActiveLearningSession(
            proposal: proposal,
            songTitle: song.name,
            songIdentifier: songIdentifier(song),
            artist: song.artistName,
            outputIdentity: currentOutputIdentity(),
            outputKind: measuredFeatures?.outputKind ?? EQManager.shared.currentOutputKind.rawValue,
            genreHints: measuredFeatures?.genreHints ?? [],
            instrumentHints: measuredFeatures?.instrumentHints ?? [],
            startedAt: Date(),
            trackDuration: max(PlayerManager.shared.duration, Double(song.dt ?? 0) / 1_000),
            lastPosition: PlaybackTimePublisher.shared.currentTime,
            listenedSeconds: 0,
            hasExplicitFeedback: previousFeedback != nil
        )
    }

    func updateLearningPlaybackPosition(_ position: Double) {
        guard adaptiveLearningEnabled,
              var session = activeLearningSession,
              session.songIdentifier == observedSongIdentifier else { return }
        defer {
            session.lastPosition = position
            activeLearningSession = session
        }
        guard PlayerManager.shared.isPlaying,
              !PlayerManager.shared.isLoading else { return }
        let delta = position - session.lastPosition
        // Count only continuous playback ticks. Seeks and track-position resets
        // are excluded so they cannot become false positive feedback.
        if delta >= 0.02, delta <= 2.5 {
            session.listenedSeconds += delta
        }
    }

    func captureManualEqualizerAdjustment(_ adjustment: EQGraphicGainUserAdjustment) {
        guard adaptiveLearningEnabled,
              learnsFromAdjustmentActions,
              let song = PlayerManager.shared.currentSong else { return }
        let identifier = songIdentifier(song)
        let outputIdentity = currentOutputIdentity()
        let matchesPendingContext = pendingManualEqualizerLearning.map {
            $0.songIdentifier == identifier
                && $0.outputIdentity == outputIdentity
                && $0.graphicEQMode == adjustment.graphicEQMode
        } ?? false
        if !matchesPendingContext {
            flushPendingManualEqualizerLearning()
        }

        if var pending = pendingManualEqualizerLearning {
            pending.adjustedGains = adjustment.adjustedGains
            pending.changedAt = adjustment.changedAt
            pendingManualEqualizerLearning = pending
        } else {
            let features = measuredFeatures.flatMap { measured -> AIEqualizerAudioFeatures? in
                measured.songID == song.id && measured.graphicEQMode == adjustment.graphicEQMode
                    ? measured
                    : nil
            }
            let effects = PlayerManager.shared.audioEffects
            pendingManualEqualizerLearning = AIEqualizerPendingManualAdjustment(
                songTitle: song.name,
                songIdentifier: identifier,
                artist: song.artistName,
                outputIdentity: outputIdentity,
                outputKind: features?.outputKind ?? EQManager.shared.currentOutputKind.rawValue,
                graphicEQMode: adjustment.graphicEQMode,
                genreHints: features?.genreHints ?? [],
                instrumentHints: features?.instrumentHints ?? [],
                previousGains: adjustment.previousGains,
                adjustedGains: adjustment.adjustedGains,
                bassGain: effects.bassGain,
                trebleGain: effects.trebleGain,
                surroundLevel: effects.surroundLevel,
                reverbLevel: effects.reverbLevel,
                stereoWidth: effects.stereoWidth,
                processingIntensity: EQManager.shared.professionalProcessingIntensity,
                changedAt: adjustment.changedAt
            )
        }
        activeLearningSession?.hasExplicitFeedback = true
        currentLearningFeedback = .manualEqualizer
        scheduleManualEqualizerLearningCommit()
    }

    func scheduleManualEqualizerLearningCommit() {
        manualEqualizerLearningTask?.cancel()
        manualEqualizerLearningTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            self?.flushPendingManualEqualizerLearning()
        }
    }

    func flushPendingManualEqualizerLearning() {
        manualEqualizerLearningTask?.cancel()
        manualEqualizerLearningTask = nil
        guard let pending = pendingManualEqualizerLearning else { return }
        pendingManualEqualizerLearning = nil
        guard learningStore.recordManualEqualizerAdjustment(pending) else { return }
        // The cloud sample for the proposal the listener was hearing gets the
        // curve they settled on; the trainer turns it into a delta label.
        if let heard = activeLearningSession?.proposal ?? proposal,
           heard.graphicEQMode == pending.graphicEQMode,
           heard.gains.count == pending.adjustedGains.count {
            proposalCache.recordTrainingOutcome(
                proposalID: heard.id,
                feedback: .manualEqualizer,
                listenedSeconds: activeLearningSession?.listenedSeconds ?? 0,
                manualGainsDB: pending.adjustedGains
            )
        }
        refreshLearningRecords()
        let maximumDelta = zip(pending.previousGains, pending.adjustedGains)
            .map { abs($0 - $1) }
            .max() ?? 0
        AppLogger.info(
            "[AIEqualizerAgent] Manual equalizer preference recorded song=\(pending.songIdentifier) mode=\(pending.graphicEQMode.rawValue) maxDelta=\(String(format: "%.2f", maximumDelta))dB revision=\(learningStore.revision)",
            step: "ai-tuning.learning-manual-eq"
        )
    }

    func discardPendingManualEqualizerLearning() {
        manualEqualizerLearningTask?.cancel()
        manualEqualizerLearningTask = nil
        pendingManualEqualizerLearning = nil
    }

    func finalizeRetainedLearningSession() {
        guard adaptiveLearningEnabled,
              learnsFromListeningBehavior,
              let session = activeLearningSession else {
            activeLearningSession = nil
            return
        }
        defer { activeLearningSession = nil }
        guard !session.hasExplicitFeedback else { return }
        let retentionThreshold = min(90, max(35, session.trackDuration * 0.28))
        guard session.listenedSeconds >= retentionThreshold else { return }
        persistLearningFeedback(.retained, session: session)
    }

    func recordImplicitFeedbackIfNeeded(_ feedback: AIEqualizerLearningFeedback) {
        guard adaptiveLearningEnabled,
              learnsFromAdjustmentActions,
              let session = activeLearningSession,
              appliedProposalID == session.proposal.id else { return }
        persistLearningFeedback(feedback, session: session)
        activeLearningSession?.hasExplicitFeedback = true
        currentLearningFeedback = feedback
    }

    func recordFeedbackIfPossible(_ feedback: AIEqualizerLearningFeedback) {
        guard adaptiveLearningEnabled, learnsFromExplicitFeedback else { return }
        let session: AIEqualizerActiveLearningSession
        if let activeLearningSession,
           activeLearningSession.proposal.id == proposal?.id {
            session = activeLearningSession
        } else if let proposal,
                  let song = PlayerManager.shared.currentSong {
            session = AIEqualizerActiveLearningSession(
                proposal: proposal,
                songTitle: song.name,
                songIdentifier: songIdentifier(song),
                artist: song.artistName,
                outputIdentity: currentOutputIdentity(),
                outputKind: measuredFeatures?.outputKind ?? EQManager.shared.currentOutputKind.rawValue,
                genreHints: measuredFeatures?.genreHints ?? [],
                instrumentHints: measuredFeatures?.instrumentHints ?? [],
                startedAt: Date(),
                trackDuration: max(PlayerManager.shared.duration, Double(song.dt ?? 0) / 1_000),
                lastPosition: PlaybackTimePublisher.shared.currentTime,
                listenedSeconds: 0,
                hasExplicitFeedback: true
            )
        } else {
            return
        }
        persistLearningFeedback(feedback, session: session)
        activeLearningSession?.hasExplicitFeedback = true
        currentLearningFeedback = feedback
        HapticManager.shared.success()
    }

    func persistLearningFeedback(
        _ feedback: AIEqualizerLearningFeedback,
        session: AIEqualizerActiveLearningSession
    ) {
        learningStore.record(feedback: feedback, session: session)
        proposalCache.recordTrainingOutcome(
            proposalID: session.proposal.id,
            feedback: feedback,
            listenedSeconds: session.listenedSeconds
        )
        refreshLearningRecords()
        let listenedText = String(format: "%.1f", session.listenedSeconds)
        AppLogger.info(
            "[AIEqualizerAgent] Learning feedback recorded feedback=\(feedback.rawValue) proposal=\(session.proposal.id.uuidString) listened=\(listenedText)s revision=\(learningStore.revision) evidence=\(learningEvidenceCount)",
            step: "ai-tuning.learning-feedback"
        )
    }

    func refreshLearningRecords() {
        learningStore.hydrateSongMetadata(
            from: learningSongMetadata(in: PlayerManager.shared)
        )
        learningEvidenceCount = learningStore.evidenceCount
        learningRecords = learningStore.records
    }

    func learningSongMetadata(
        in player: PlayerManager
    ) -> [String: AIEqualizerLearningSongMetadata] {
        var metadata = measurementStore.learningSongMetadata
        var songs = player.currentContextList
        songs.append(contentsOf: player.history)
        songs.append(contentsOf: player.podcastHistory)
        if let currentSong = player.currentSong {
            songs.insert(currentSong, at: 0)
        }

        var seen = Set<String>()
        for song in songs {
            let identifier = songIdentifier(song)
            guard seen.insert(identifier).inserted else { continue }
            metadata[identifier] = AIEqualizerLearningSongMetadata(
                title: song.name,
                artist: song.artistName
            )
        }
        return metadata
    }

    func recordProfileName(_ name: String) {
        recentProfileNames.removeAll { $0 == name }
        recentProfileNames.append(name)
        recentProfileNames = Array(recentProfileNames.suffix(16))
        UserDefaults.standard.set(recentProfileNames, forKey: Self.recentProfileNamesKey)
    }

    func songIdentifier(_ song: Song) -> String {
        "\(song.musicSource.rawValue):\(song.id)"
    }

    func currentOutputIdentity() -> String {
        let manager = EQManager.shared
        let baseIdentity = manager.currentOutputName.isEmpty
            ? manager.currentOutputKind.rawValue
            : "\(manager.currentOutputKind.rawValue):\(manager.currentOutputName)"
        let profileIdentity = manager.resolvedHeadphoneProfile?.id ?? "none"
        let calibrationIdentity = manager.isOutputCalibrationEnabled ? "on" : "off"
        let target = AirPodsExperienceManager.currentAITuningTargetSnapshot()
        let targetIdentity = target?.identifier ?? "none"
        let context = manager.aiEqualizerDeviceTrainingContext(deviceTuningTarget: target)
        let curveIdentity = context.effectiveGainsDB
            .map { String(format: "%.3f", $0) }
            .joined(separator: ",")
        let filterIdentity = context.acousticFilters.map {
            "\($0.kind):\(String(format: "%.2f", $0.frequencyHz)):\(String(format: "%.3f", $0.gainDB)):\(String(format: "%.3f", $0.q)):\(String(format: "%.2f", $0.slopeDBPerOctave))"
        }.joined(separator: "|")
        let fingerprintData = Data("\(curveIdentity)|\(context.profilePreampDB)|\(filterIdentity)".utf8)
        let deviceFingerprint = SHA256.hash(data: fingerprintData)
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(baseIdentity)|calibration:\(calibrationIdentity)|profile:\(profileIdentity)|target:\(targetIdentity)|device:\(deviceFingerprint)"
    }

    /// Binds the model context, remote policy, bundled knowledge, and local
    /// skill selection into one immutable identity for this tuning request.
    /// This is intentionally synchronous and performs no network or sampling
    /// work, so enabling skills does not add tuning latency.
}
