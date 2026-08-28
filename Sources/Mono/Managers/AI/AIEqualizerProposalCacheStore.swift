import Foundation
@preconcurrency import Combine
import FFmpegSwiftSDK
import UIKit


/// A malformed or obsolete persisted entry must not make sibling entries
/// undecodable. The durable proposal model supplies migration defaults; this
/// wrapper contains damage when an individual record is genuinely corrupt.
struct LossyDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

@MainActor
final class AIEqualizerProposalCacheStore {
    private static let storageKey = "ai.eq.agent.proposal-cache.v1"
    private static let historyStorageKey = "ai.eq.agent.proposal-history.v1"
    private static let maximumAge: TimeInterval = 45 * 24 * 60 * 60

    private var values: [String: AIEqualizerProposal]
    private var histories: [String: [AIEqualizerSavedProposal]]

    init() {
        values = Self.restoreCachedProposals()
        histories = Self.restoreSavedProposalHistory()
        removeExpiredEntries()
    }

    func value(
        for key: String,
        agentVersion: String,
        skillFingerprint: String,
        skillRevision: String,
        now: Date = Date()
    ) -> AIEqualizerProposal? {
        guard let value = values[key] else { return nil }
        guard now.timeIntervalSince(value.createdAt) <= Self.maximumAge else {
            values.removeValue(forKey: key)
            persist()
            return nil
        }
        guard value.agentVersion == agentVersion,
              value.skillFingerprint == skillFingerprint,
              value.skillRevision == skillRevision,
              Self.hasCurrentSkillCompliance(value) else {
            return nil
        }
        return value
    }

    func set(_ value: AIEqualizerProposal, for key: String) {
        values[key] = value
        removeExpiredEntries()
        persist()
    }

    func record(
        _ proposal: AIEqualizerProposal,
        songIdentifier: String,
        outputIdentity: String
    ) {
        let entry = AIEqualizerSavedProposal(
            proposal: proposal,
            songIdentifier: songIdentifier,
            outputIdentity: outputIdentity
        )
        var entries = histories[songIdentifier] ?? []
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        histories[songIdentifier] = entries.sorted {
            $0.proposal.createdAt > $1.proposal.createdAt
        }
        persistHistory()
    }

    func shouldRecord(
        _ proposal: AIEqualizerProposal,
        songIdentifier: String,
        outputIdentity: String
    ) -> Bool {
        guard let previous = histories[songIdentifier]?
            .sorted(by: { $0.proposal.createdAt > $1.proposal.createdAt })
            .first(where: {
                $0.outputIdentity == outputIdentity
                    && $0.proposal.graphicEQMode == proposal.graphicEQMode
                    && ($0.proposal.tuningIntensity ?? .smart) == (proposal.tuningIntensity ?? .smart)
                    && ($0.proposal.tuningProfile ?? .standard) == (proposal.tuningProfile ?? .standard)
                    && $0.proposal.provider == proposal.provider
                    && $0.proposal.model == proposal.model
                    && $0.proposal.agentVersion == proposal.agentVersion
                    && $0.proposal.skillFingerprint == proposal.skillFingerprint
                    && $0.proposal.skillRevision == proposal.skillRevision
                    && Self.hasCurrentSkillCompliance($0.proposal)
            }) else {
            return true
        }
        return Self.hasMeaningfulDifference(proposal, previous.proposal)
    }

    func history(for songIdentifier: String, now: Date = Date()) -> [AIEqualizerSavedProposal] {
        removeExpiredEntries(now: now)
        return histories[songIdentifier, default: []]
            .sorted { $0.proposal.createdAt > $1.proposal.createdAt }
    }

    func delete(_ entry: AIEqualizerSavedProposal, for songIdentifier: String) {
        histories[songIdentifier]?.removeAll { $0.id == entry.id }
        if histories[songIdentifier]?.isEmpty == true {
            histories.removeValue(forKey: songIdentifier)
        }
        values = values.filter { $0.value.id != entry.id }
        persist()
        persistHistory()
    }

    func deleteAll(for songIdentifier: String) {
        let ids = Set(histories[songIdentifier, default: []].map(\.id))
        histories.removeValue(forKey: songIdentifier)
        values = values.filter { !ids.contains($0.value.id) }
        persist()
        persistHistory()
    }

    var hasStoredProposals: Bool {
        !values.isEmpty || !histories.isEmpty
    }

    func deleteAll() {
        values.removeAll()
        histories.removeAll()
        persist()
        persistHistory()
    }

    func makeCloudSnapshot() -> CloudAIEqualizerSnapshot? {
        removeExpiredEntries()
        guard !values.isEmpty || !histories.isEmpty else { return nil }
        return CloudAIEqualizerSnapshot(
            cachedProposals: values,
            savedProposals: histories
        )
    }

    func mergeCloudSnapshot(_ snapshot: CloudAIEqualizerSnapshot) {
        for (key, proposal) in snapshot.cachedProposals {
            if let local = values[key], local.createdAt >= proposal.createdAt {
                continue
            }
            values[key] = proposal
        }

        for (songIdentifier, remoteEntries) in snapshot.savedProposals {
            let localEntries = histories[songIdentifier, default: []]
            let merged = Dictionary(
                (localEntries + remoteEntries).map { ($0.id, $0) },
                uniquingKeysWith: { current, candidate in
                    current.proposal.createdAt >= candidate.proposal.createdAt ? current : candidate
                }
            )
            histories[songIdentifier] = merged.values.sorted {
                $0.proposal.createdAt > $1.proposal.createdAt
            }
        }

        removeExpiredEntries()
        persist()
        persistHistory()
    }

    private func removeExpiredEntries(now: Date = Date()) {
        let originalValueCount = values.count
        values = values.filter { now.timeIntervalSince($0.value.createdAt) <= Self.maximumAge }
        if values.count != originalValueCount {
            persist()
        }
    }

    private static func hasMeaningfulDifference(
        _ current: AIEqualizerProposal,
        _ previous: AIEqualizerProposal
    ) -> Bool {
        guard current.graphicEQMode == previous.graphicEQMode else { return true }

        let bandDeltas = zip(current.gains, previous.gains).map { abs($0 - $1) }
        let changedBandCount = bandDeltas.filter { $0 >= 0.35 }.count
        if (bandDeltas.max() ?? 0) >= 0.55 || changedBandCount >= 2 {
            return true
        }

        if abs(current.preampDB - previous.preampDB) >= 0.4
            || abs(current.tone.bassGain - previous.tone.bassGain) >= 0.4
            || abs(current.tone.trebleGain - previous.tone.trebleGain) >= 0.4
            || abs(current.spatial.surroundLevel - previous.spatial.surroundLevel) >= 0.06
            || abs(current.spatial.reverbLevel - previous.spatial.reverbLevel) >= 0.06
            || abs(current.spatial.stereoWidth - previous.spatial.stereoWidth) >= 0.05
            || abs(current.professional.processingIntensity - previous.professional.processingIntensity) >= 0.06 {
            return true
        }

        let enhanceDeltas = [
            abs(current.enhance.transientAttack - previous.enhance.transientAttack),
            abs(current.enhance.transientSustain - previous.enhance.transientSustain),
            abs(current.enhance.vocalFocus - previous.enhance.vocalFocus),
            abs(current.enhance.airAmount - previous.enhance.airAmount),
            abs(current.enhance.deEssAmount - previous.enhance.deEssAmount),
            abs(current.enhance.lowFrequencyFocus - previous.enhance.lowFrequencyFocus),
            abs(current.enhance.stageWidth - previous.enhance.stageWidth),
            abs(current.enhance.microDynamics - previous.enhance.microDynamics),
            abs(current.enhance.lowLevelCompensation - previous.enhance.lowLevelCompensation)
        ]
        if current.enhance.isEnabled != previous.enhance.isEnabled
            || (enhanceDeltas.max() ?? 0) >= 0.05
            || current.calibration != previous.calibration
            || current.professional.dynamicEQ.enabled != previous.professional.dynamicEQ.enabled
            || current.professional.multiband.enabled != previous.professional.multiband.enabled
            || current.professional.parametricEQ.enabled != previous.professional.parametricEQ.enabled {
            return true
        }

        let currentEffects = current.effects
        let previousEffects = previous.effects
        if currentEffects.loudnessNormalizationEnabled != previousEffects.loudnessNormalizationEnabled
            || currentEffects.compressorEnabled != previousEffects.compressorEnabled
            || currentEffects.subboostEnabled != previousEffects.subboostEnabled
            || currentEffects.virtualBassEnabled != previousEffects.virtualBassEnabled
            || currentEffects.bs2bEnabled != previousEffects.bs2bEnabled
            || currentEffects.crossfeedEnabled != previousEffects.crossfeedEnabled
            || currentEffects.haasEnabled != previousEffects.haasEnabled
            || currentEffects.exciterEnabled != previousEffects.exciterEnabled
            || currentEffects.softclipEnabled != previousEffects.softclipEnabled
            || currentEffects.finalLimiterEnabled != previousEffects.finalLimiterEnabled {
            return true
        }

        return abs(currentEffects.subboostGainDB - previousEffects.subboostGainDB) >= 0.5
            || abs(currentEffects.exciterAmountDB - previousEffects.exciterAmountDB) >= 0.5
            || abs(currentEffects.finalLimiterCeilingDB - previousEffects.finalLimiterCeilingDB) >= 0.5
    }

    private static func hasCurrentSkillCompliance(
        _ proposal: AIEqualizerProposal
    ) -> Bool {
        guard let compliance = proposal.skillCompliance,
              compliance.accepted,
              compliance.knowledgeVersion == MonoAudioTuningKnowledge.version,
              compliance.toolVersion == MonoAudioTuningTool.version,
              compliance.checkedRuleCount >= MonoAudioTuningKnowledge.enforcedRuleCount,
              compliance.localValidationApplied,
              Set(compliance.requiredSkillIDs).isSubset(of: Set(compliance.enabledSkillIDs)) else {
            return false
        }
        switch compliance.executionMode {
        case .requiredModelTool:
            return proposal.provider != .appleIntelligence
                && compliance.modelToolInvocationCount == 1
        case .modelPromptFallback:
            return proposal.provider != .appleIntelligence
                && compliance.modelToolInvocationCount == 0
        case .appleIntelligenceLocalCompiler:
            return proposal.provider == .appleIntelligence
                && compliance.modelToolInvocationCount == 1
        }
    }

    private static func restoreCachedProposals() -> [String: AIEqualizerProposal] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        do {
            let decoded = try JSONDecoder().decode(
                [String: LossyDecodable<AIEqualizerProposal>].self,
                from: data
            )
            let restored = decoded.compactMapValues(\.value)
            if restored.count != decoded.count {
                AppLogger.warning(
                    "[AIEqualizerAgent] Skipped \(decoded.count - restored.count) corrupt cached proposals while preserving \(restored.count)",
                    step: "ai-tuning.proposal-restore"
                )
            }
            return restored
        } catch {
            AppLogger.error(
                "[AIEqualizerAgent] Cached proposal archive could not be decoded; original data was left untouched error=\(error.localizedDescription)",
                step: "ai-tuning.proposal-restore-failed"
            )
            return [:]
        }
    }

    private static func restoreSavedProposalHistory() -> [String: [AIEqualizerSavedProposal]] {
        guard let data = UserDefaults.standard.data(forKey: historyStorageKey) else { return [:] }
        do {
            let decoded = try JSONDecoder().decode(
                [String: [LossyDecodable<AIEqualizerSavedProposal>]].self,
                from: data
            )
            var skippedCount = 0
            let restored = decoded.reduce(
                into: [String: [AIEqualizerSavedProposal]]()
            ) { result, item in
                let entries = item.value.compactMap(\.value)
                skippedCount += item.value.count - entries.count
                if !entries.isEmpty {
                    result[item.key] = entries
                }
            }
            if skippedCount > 0 {
                let restoredCount = restored.values.reduce(0) { $0 + $1.count }
                AppLogger.warning(
                    "[AIEqualizerAgent] Skipped \(skippedCount) corrupt saved proposals while preserving \(restoredCount)",
                    step: "ai-tuning.proposal-history-restore"
                )
            }
            return restored
        } catch {
            AppLogger.error(
                "[AIEqualizerAgent] Saved proposal archive could not be decoded; original data was left untouched error=\(error.localizedDescription)",
                step: "ai-tuning.proposal-history-restore-failed"
            )
            return [:]
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(histories) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyStorageKey)
    }
}
