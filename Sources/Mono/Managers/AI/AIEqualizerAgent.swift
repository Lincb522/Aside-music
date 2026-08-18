import Foundation
@preconcurrency import Combine
import FFmpegSwiftSDK
import UIKit

private enum AIEqualizerAnalysisTrigger: Equatable {
    case manual
    case automatic

    var logName: String {
        switch self {
        case .manual: return "manual"
        case .automatic: return "automatic"
        }
    }
}

@MainActor
final class AIEqualizerAgent: ObservableObject {
    static let shared = AIEqualizerAgent()

    @Published private(set) var phase: AIEqualizerAgentPhase = .idle
    @Published private(set) var proposal: AIEqualizerProposal?
    @Published private(set) var savedProposals: [AIEqualizerSavedProposal] = []
    @Published private(set) var measuredFeatures: AIEqualizerAudioFeatures?
    @Published private(set) var appliedProposalID: UUID?
    @Published private(set) var samplingStage: AIEqualizerSamplingStage = .preparing
    @Published private(set) var generationStage: AIEqualizerGenerationStage = .preparing
    @Published private(set) var tuningStartedAt: Date?
    @Published private(set) var generationStartedAt: Date?
    @Published private(set) var currentLearningFeedback: AIEqualizerLearningFeedback?
    @Published private(set) var learningEvidenceCount = 0
    @Published var adaptiveLearningEnabled: Bool {
        didSet {
            UserDefaults.standard.set(adaptiveLearningEnabled, forKey: Self.adaptiveLearningKey)
            if !adaptiveLearningEnabled {
                activeLearningSession = nil
                currentLearningFeedback = nil
            }
            AppLogger.info(
                "[AIEqualizerAgent] Adaptive learning enabled=\(adaptiveLearningEnabled)",
                step: "ai-tuning.learning-toggle"
            )
        }
    }
    @Published var tuningIntensity: AIEqualizerTuningIntensity {
        didSet {
            UserDefaults.standard.set(tuningIntensity.rawValue, forKey: Self.tuningIntensityKey)
            AppLogger.info(
                "[AIEqualizerAgent] Tuning intensity changed value=\(tuningIntensity.rawValue)",
                step: "ai-tuning.intensity"
            )
        }
    }
    @Published private(set) var tuningProfile: AIEqualizerTuningProfile {
        didSet {
            UserDefaults.standard.set(tuningProfile.rawValue, forKey: Self.tuningProfileKey)
            AppLogger.info(
                "[AIEqualizerAgent] Tuning profile changed value=\(tuningProfile.rawValue)",
                step: "ai-tuning.profile"
            )
        }
    }
    @Published var samplingMode: AIEqualizerSamplingMode {
        didSet { UserDefaults.standard.set(samplingMode.rawValue, forKey: Self.samplingModeKey) }
    }
    @Published var customSamplingDuration: Double {
        didSet {
            let normalized = min(120, max(10, customSamplingDuration))
            UserDefaults.standard.set(normalized, forKey: Self.customSamplingDurationKey)
        }
    }
    @Published var showsPlayerTuningStatus: Bool {
        didSet {
            UserDefaults.standard.set(showsPlayerTuningStatus, forKey: Self.playerStatusKey)
        }
    }
    @Published var automaticConfigurationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automaticConfigurationEnabled, forKey: Self.autoKey)
            AppLogger.info(
                "[AIEqualizerAgent] Automatic tuning enabled=\(automaticConfigurationEnabled)",
                step: "ai-tuning.automation"
            )
            if automaticConfigurationEnabled {
                scheduleAutomaticAnalysis()
            } else {
                automaticTask?.cancel()
                analysisTask?.cancel()
                automaticRetryTask?.cancel()
                activeAnalysisRunID = nil
                activeAnalysisSongIdentifier = nil
                tuningStartedAt = nil
                scheduledAutomaticRunID = nil
                scheduledAutomaticSongIdentifier = nil
                if phase.isWorking { phase = .idle }
                EQManager.shared.restoreProcessingBeforeAI(reason: "automatic-disabled")
                appliedProposalID = nil
                appliedSongIdentifier = nil
                activeLearningSession = nil
                currentLearningFeedback = nil
            }
        }
    }

    private static let autoKey = "ai.eq.agent.auto-configure"
    private static let samplingModeKey = "ai.eq.agent.sampling-mode"
    private static let tuningIntensityKey = "ai.eq.agent.tuning-intensity"
    private static let tuningProfileKey = "ai.eq.agent.tuning-profile"
    private static let customSamplingDurationKey = "ai.eq.agent.custom-sampling-duration"
    private static let playerStatusKey = "ai.eq.agent.player-status"
    private static let adaptiveLearningKey = "ai.eq.agent.adaptive-learning"
    private static let recentProfileNamesKey = "ai.eq.agent.recent-profile-names.v1"
    private static let maxSamplingRetryAttempts = 3
    private static let maxGenerationRetryAttempts = 3
    private let sampler = AIEqualizerFeatureSampler()
    private let client = AIProviderClient()
    private let providerStore = AIProviderConfigurationStore.shared
    private let usageLimiter = AIUsageLimiter.shared
    private var activePromptVersion: String {
        SongContentConfigurationStore.cachedAgentConfiguration(.equalizer)?.promptVersion
            ?? AIEqualizerPrompt.version
    }
    private var cancellables = Set<AnyCancellable>()
    private var analysisTask: Task<Void, Never>?
    private var automaticTask: Task<Void, Never>?
    private var automaticRetryTask: Task<Void, Never>?
    private let proposalCache = AIEqualizerProposalCacheStore()
    private let measurementStore = AIEqualizerMeasurementStore()
    private let learningStore = AIEqualizerLearningStore()
    private var activeAnalysisRunID: UUID?
    private var activeAnalysisSongIdentifier: String?
    private var scheduledAutomaticRunID: UUID?
    private var scheduledAutomaticSongIdentifier: String?
    private var appliedSongIdentifier: String?
    private var observedSongIdentifier: String?
    private var samplingRetryCount: [String: Int] = [:]
    private var recentProfileNames: [String] = []
    private var discoveredProviderModels: [String: String] = [:]
    private var activeLearningSession: AIEqualizerActiveLearningSession?

    private init() {
        let defaults = UserDefaults.standard
        automaticConfigurationEnabled = defaults.bool(forKey: Self.autoKey)
        tuningIntensity = defaults.string(forKey: Self.tuningIntensityKey)
            .flatMap(AIEqualizerTuningIntensity.init(rawValue:)) ?? .smart
        tuningProfile = defaults.string(forKey: Self.tuningProfileKey)
            .flatMap(AIEqualizerTuningProfile.init(rawValue:)) ?? .standard
        samplingMode = defaults.string(forKey: Self.samplingModeKey)
            .flatMap(AIEqualizerSamplingMode.init(rawValue:)) ?? .smart
        let savedDuration = defaults.double(forKey: Self.customSamplingDurationKey)
        customSamplingDuration = savedDuration > 0 ? min(120, max(10, savedDuration)) : 36
        showsPlayerTuningStatus = defaults.object(forKey: Self.playerStatusKey) == nil
            ? true
            : defaults.bool(forKey: Self.playerStatusKey)
        adaptiveLearningEnabled = defaults.object(forKey: Self.adaptiveLearningKey) == nil
            ? true
            : defaults.bool(forKey: Self.adaptiveLearningKey)
        learningEvidenceCount = learningStore.evidenceCount
        recentProfileNames = Array(
            (defaults.stringArray(forKey: Self.recentProfileNamesKey) ?? []).suffix(16)
        )
        if !automaticConfigurationEnabled {
            EQManager.shared.restoreProcessingBeforeAI(reason: "agent-restored-disabled")
        }

        let player = PlayerManager.shared
        observedSongIdentifier = player.currentSong.map { "\($0.musicSource.rawValue):\($0.id)" }
        if let observedSongIdentifier {
            savedProposals = proposalCache.history(for: observedSongIdentifier)
        }
        if let song = player.currentSong {
            measuredFeatures = restoredMeasurement(for: song)
        }
        player.$currentSong
            .map { song in
                song.map { "\($0.musicSource.rawValue):\($0.id)" }
            }
            .removeDuplicates()
            .sink { [weak self] identifier in
                guard let self else { return }
                guard self.observedSongIdentifier != identifier else { return }
                self.finalizeRetainedLearningSession()
                self.observedSongIdentifier = identifier
                self.analysisTask?.cancel()
                self.automaticTask?.cancel()
                self.automaticRetryTask?.cancel()
                self.activeAnalysisRunID = nil
                self.activeAnalysisSongIdentifier = nil
                self.tuningStartedAt = nil
                self.scheduledAutomaticRunID = nil
                self.scheduledAutomaticSongIdentifier = nil
                if let identifier,
                   self.automaticConfigurationEnabled,
                   PlayerManager.shared.currentSong?.isAppleMusic != true {
                    EQManager.shared.prepareForAIAnalysis(songIdentifier: identifier)
                } else {
                    EQManager.shared.restoreProcessingBeforeAI(
                        reason: identifier == nil ? "queue-cleared" : "automatic-inactive"
                    )
                }
                self.proposal = nil
                self.measuredFeatures = PlayerManager.shared.currentSong.flatMap {
                    self.restoredMeasurement(for: $0)
                }
                self.savedProposals = identifier.map { self.proposalCache.history(for: $0) } ?? []
                self.appliedProposalID = nil
                self.appliedSongIdentifier = nil
                self.currentLearningFeedback = nil
                self.samplingRetryCount.removeAll()
                self.samplingStage = .preparing
                self.generationStage = .preparing
                self.phase = .idle
            }
            .store(in: &cancellables)

        PlaybackTimePublisher.shared.$currentTime
            .sink { [weak self] position in
                self?.updateLearningPlaybackPosition(position)
            }
            .store(in: &cancellables)

        player.$currentPlayingURL
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self,
                      !self.phase.isWorking,
                      let song = PlayerManager.shared.currentSong,
                      let restored = self.restoredMeasurement(for: song) else { return }
                self.measuredFeatures = restored
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            player.$currentSong,
            player.$isPlaying.removeDuplicates(),
            player.$isLoading.removeDuplicates()
        )
        .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
        .sink { [weak self] readiness in
            let (song, isPlaying, isLoading) = readiness
            guard let self,
                  self.automaticConfigurationEnabled,
                  song != nil,
                  isPlaying,
                  !isLoading else { return }
            self.scheduleAutomaticAnalysis()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest(
            EQManager.shared.$currentOutputKind,
            EQManager.shared.$currentOutputName
        )
        .map { output in "\(output.0.rawValue):\(output.1)" }
        .removeDuplicates()
        .dropFirst()
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self,
                  let currentSong = PlayerManager.shared.currentSong else { return }
            guard self.automaticConfigurationEnabled else {
                self.measuredFeatures = self.restoredMeasurement(for: currentSong)
                return
            }
            self.analysisTask?.cancel()
            self.automaticTask?.cancel()
            self.automaticRetryTask?.cancel()
            self.activeAnalysisRunID = nil
            self.activeAnalysisSongIdentifier = nil
            self.tuningStartedAt = nil
            self.scheduledAutomaticRunID = nil
            self.scheduledAutomaticSongIdentifier = nil
            self.finalizeRetainedLearningSession()
            EQManager.shared.restoreProcessingBeforeAI(reason: "output-changed")
            self.proposal = nil
            self.measuredFeatures = PlayerManager.shared.currentSong.flatMap {
                self.restoredMeasurement(for: $0)
            }
            self.appliedProposalID = nil
            self.appliedSongIdentifier = nil
            self.currentLearningFeedback = nil
            self.samplingRetryCount.removeAll()
            self.phase = .idle
            self.scheduleAutomaticAnalysis()
        }
        .store(in: &cancellables)

        EQManager.shared.$graphicEQMode
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] mode in
                guard let self else { return }
                self.analysisTask?.cancel()
                self.automaticTask?.cancel()
                self.automaticRetryTask?.cancel()
                self.activeAnalysisRunID = nil
                self.activeAnalysisSongIdentifier = nil
                self.tuningStartedAt = nil
                self.scheduledAutomaticRunID = nil
                self.scheduledAutomaticSongIdentifier = nil
                self.finalizeRetainedLearningSession()
                self.proposal = nil
                self.measuredFeatures = PlayerManager.shared.currentSong.flatMap {
                    self.restoredMeasurement(for: $0, graphicEQMode: mode)
                }
                self.appliedProposalID = nil
                self.appliedSongIdentifier = nil
                self.currentLearningFeedback = nil
                self.samplingRetryCount.removeAll()
                self.phase = .idle
                AppLogger.info(
                    "[AIEqualizerAgent] Graphic EQ mode changed bands=\(mode.bandCount)",
                    step: "ai-tuning.eq-mode"
                )
                if self.automaticConfigurationEnabled,
                   PlayerManager.shared.currentSong != nil {
                    self.scheduleAutomaticAnalysis()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        analysisTask?.cancel()
        automaticTask?.cancel()
        automaticRetryTask?.cancel()
    }

    var isCurrentProposalApplied: Bool {
        guard let proposal else { return false }
        return appliedProposalID == proposal.id
            && EQManager.shared.isActivelyApplyingAIProposal(proposal)
    }

    var applicableSavedProposals: [AIEqualizerSavedProposal] {
        guard let song = PlayerManager.shared.currentSong else { return [] }
        let identifier = songIdentifier(song)
        return savedProposals.filter {
            $0.songIdentifier == identifier
        }
    }

    var hasAnySavedProposals: Bool {
        proposalCache.hasStoredProposals
    }

    func selectTuningProfile(_ profile: AIEqualizerTuningProfile) {
        let selectionChanged = tuningProfile != profile
        let appliedProfileMatches = proposal?.resolvedTuningProfile == profile
            && isCurrentProposalApplied
        guard selectionChanged || !appliedProfileMatches else { return }
        if selectionChanged {
            tuningProfile = profile
        }

        automaticTask?.cancel()
        automaticRetryTask?.cancel()
        analysisTask?.cancel()
        analysisTask = nil
        activeAnalysisRunID = nil
        activeAnalysisSongIdentifier = nil
        scheduledAutomaticRunID = nil
        scheduledAutomaticSongIdentifier = nil
        tuningStartedAt = nil
        generationStartedAt = nil
        activeLearningSession = nil
        currentLearningFeedback = nil

        guard automaticConfigurationEnabled,
              let song = PlayerManager.shared.currentSong else {
            if phase.isWorking { phase = .idle }
            return
        }

        let identifier = songIdentifier(song)
        let outputIdentity = currentOutputIdentity()
        let graphicEQMode = EQManager.shared.graphicEQMode
        samplingRetryCount[identifier] = nil

        if let saved = proposalCache.latestReusable(
            for: identifier,
            outputIdentity: outputIdentity,
            graphicEQMode: graphicEQMode,
            tuningIntensity: tuningIntensity,
            tuningProfile: profile
        ) {
            let generatedAgentVersion = saved.proposal.agentVersion ?? "legacy"
            let requiresSpatialUpgrade = profile == .monoSpatialEnhancement
                && generatedAgentVersion != activePromptVersion
            if !requiresSpatialUpgrade {
                proposal = saved.proposal
                AppLogger.info(
                    "[AIEqualizerAgent] Tuning profile selection reused saved proposal song=\(identifier) profile=\(profile.rawValue) proposal=\(saved.id.uuidString)",
                    step: "ai-tuning.profile-reuse"
                )
                apply(saved.proposal)
                return
            }
            AppLogger.info(
                "[AIEqualizerAgent] Tuning profile selection requires spatial upgrade song=\(identifier) proposal=\(saved.id.uuidString) generatedBy=\(generatedAgentVersion) currentAgent=\(activePromptVersion)",
                step: "ai-tuning.spatial-upgrade"
            )
        }

        EQManager.shared.prepareForAIAnalysis(songIdentifier: identifier)
        proposal = nil
        appliedProposalID = nil
        appliedSongIdentifier = nil
        samplingStage = .preparing
        generationStage = .preparing
        phase = .idle
        AppLogger.info(
            "[AIEqualizerAgent] Tuning profile selection requires analysis song=\(identifier) profile=\(profile.rawValue)",
            step: "ai-tuning.profile-analysis"
        )
        scheduleAutomaticAnalysis()
    }

    func analyzeCurrentSong() {
        guard PlayerManager.shared.currentSong?.isAppleMusic != true else {
            phase = .failed(
                AIEqualizerError.protectedAudioUnsupported.localizedDescription
            )
            return
        }
        recordImplicitFeedbackIfNeeded(.regenerated)
        automaticTask?.cancel()
        automaticRetryTask?.cancel()
        analysisTask?.cancel()
        samplingRetryCount.removeAll()
        measuredFeatures = nil
        proposal = nil
        scheduledAutomaticRunID = nil
        scheduledAutomaticSongIdentifier = nil
        activeAnalysisRunID = nil
        activeAnalysisSongIdentifier = nil
        tuningStartedAt = nil
        if let song = PlayerManager.shared.currentSong {
            EQManager.shared.prepareForAIAnalysis(songIdentifier: songIdentifier(song))
        }
        analysisTask = Task { [weak self] in
            await self?.runAnalysis(trigger: .manual, forceRegeneration: true)
        }
    }

    /// Invalidates only the active output-device result. Measurements remain
    /// reusable because the selected AirPods baseline is applied after spectral
    /// analysis, while proposal/cache identity changes with the selected model.
    func handleOutputTuningTargetChanged() {
        automaticTask?.cancel()
        automaticRetryTask?.cancel()
        analysisTask?.cancel()
        analysisTask = nil
        activeAnalysisRunID = nil
        activeAnalysisSongIdentifier = nil
        scheduledAutomaticRunID = nil
        scheduledAutomaticSongIdentifier = nil
        tuningStartedAt = nil
        generationStartedAt = nil
        proposal = nil
        appliedProposalID = nil
        appliedSongIdentifier = nil
        phase = .idle

        guard automaticConfigurationEnabled,
              PlayerManager.shared.currentSong != nil else { return }
        scheduleAutomaticAnalysis()
    }

    func cancelAnalysis() {
        automaticTask?.cancel()
        automaticRetryTask?.cancel()
        analysisTask?.cancel()
        analysisTask = nil
        samplingRetryCount.removeAll()
        scheduledAutomaticRunID = nil
        scheduledAutomaticSongIdentifier = nil
        activeAnalysisRunID = nil
        activeAnalysisSongIdentifier = nil
        tuningStartedAt = nil
        if phase.isWorking { phase = .idle }
        if measuredFeatures == nil,
           let song = PlayerManager.shared.currentSong {
            measuredFeatures = restoredMeasurement(for: song)
        }
    }

    func applyCurrentProposal() {
        guard let proposal else { return }
        apply(proposal, isManualAction: true)
    }

    func applySavedProposal(_ saved: AIEqualizerSavedProposal) {
        guard let song = PlayerManager.shared.currentSong,
              songIdentifier(song) == saved.songIdentifier else {
            rejectManualApply(reason: "song mismatch", saved: saved)
            return
        }
        let currentMode = EQManager.shared.graphicEQMode
        let adaptedProposal = saved.proposal.adapted(to: currentMode)
        let currentOutputIdentity = currentOutputIdentity()
        automaticTask?.cancel()
        automaticRetryTask?.cancel()
        analysisTask?.cancel()
        activeAnalysisRunID = nil
        activeAnalysisSongIdentifier = nil
        scheduledAutomaticRunID = nil
        scheduledAutomaticSongIdentifier = nil
        tuningStartedAt = nil
        tuningIntensity = adaptedProposal.tuningIntensity ?? .smart
        tuningProfile = adaptedProposal.tuningProfile ?? .standard
        proposal = adaptedProposal
        apply(adaptedProposal, isManualAction: true)
        AppLogger.info(
            "[AIEqualizerAgent] Applied saved proposal song=\(saved.songIdentifier) proposal=\(saved.id.uuidString) savedOutput=\(saved.outputIdentity) currentOutput=\(currentOutputIdentity) savedMode=\(saved.proposal.graphicEQMode.rawValue) currentMode=\(currentMode.rawValue)",
            step: "ai-tuning.saved-apply"
        )
    }

    /// 手动应用被环境变化拦下时不能无声返回：用户点了按钮，必须看到结果。
    private func rejectManualApply(reason: String, saved: AIEqualizerSavedProposal) {
        AppLogger.warning(
            "[AIEqualizerAgent] Manual apply rejected (\(reason)) proposal=\(saved.id.uuidString) song=\(saved.songIdentifier) output=\(saved.outputIdentity)",
            step: "ai-tuning.apply-skipped"
        )
        phase = .failed(String(localized: "ai_tuning_apply_context_changed"))
        HapticManager.shared.warning()
    }

    func deleteSavedProposal(_ saved: AIEqualizerSavedProposal) {
        guard let song = PlayerManager.shared.currentSong else { return }
        let identifier = songIdentifier(song)
        guard identifier == saved.songIdentifier else { return }
        proposalCache.delete(saved, for: identifier)
        savedProposals = proposalCache.history(for: identifier)
        AppLogger.info(
            "[AIEqualizerAgent] Deleted saved proposal song=\(identifier) proposal=\(saved.id.uuidString)",
            step: "ai-tuning.saved-delete"
        )
    }

    func deleteAllSavedProposalsForCurrentSong() {
        guard let song = PlayerManager.shared.currentSong else { return }
        let identifier = songIdentifier(song)
        proposalCache.deleteAll(for: identifier)
        savedProposals = []
        AppLogger.info(
            "[AIEqualizerAgent] Deleted all saved proposals song=\(identifier)",
            step: "ai-tuning.saved-delete-all"
        )
    }

    func deleteAllSavedProposals() {
        automaticTask?.cancel()
        automaticRetryTask?.cancel()
        analysisTask?.cancel()
        analysisTask = nil
        activeAnalysisRunID = nil
        activeAnalysisSongIdentifier = nil
        scheduledAutomaticRunID = nil
        scheduledAutomaticSongIdentifier = nil
        tuningStartedAt = nil
        generationStartedAt = nil
        samplingRetryCount.removeAll()
        activeLearningSession = nil
        currentLearningFeedback = nil

        proposalCache.deleteAll()
        savedProposals = []
        proposal = nil
        appliedProposalID = nil
        appliedSongIdentifier = nil
        samplingStage = .preparing
        generationStage = .preparing
        phase = .idle
        EQManager.shared.restoreProcessingBeforeAI(reason: "all-proposals-deleted")

        HapticManager.shared.success()
        AppLogger.info(
            "[AIEqualizerAgent] Deleted all saved and cached proposals",
            step: "ai-tuning.saved-delete-all-global"
        )
    }

    func recordCurrentProposalFeedback(_ feedback: AIEqualizerLearningFeedback) {
        guard feedback == .positive || feedback == .negative else { return }
        guard currentLearningFeedback != feedback else { return }
        recordFeedbackIfPossible(feedback)
    }

    func clearLearningHistory() {
        learningStore.clear()
        activeLearningSession = nil
        currentLearningFeedback = nil
        learningEvidenceCount = 0
        AppLogger.info(
            "[AIEqualizerAgent] Adaptive learning history cleared",
            step: "ai-tuning.learning-cleared"
        )
    }

    func makeCloudSnapshot() -> CloudAIEqualizerSnapshot? {
        proposalCache.makeCloudSnapshot()
    }

    func restoreCloudSnapshot(_ snapshot: CloudAIEqualizerSnapshot) {
        proposalCache.mergeCloudSnapshot(snapshot)
        savedProposals = observedSongIdentifier.map { proposalCache.history(for: $0) } ?? []
    }

    func resetToFlat() {
        recordImplicitFeedbackIfNeeded(.reset)
        EQManager.shared.restoreProcessingBeforeAI(reason: "manual-reset")
        EQManager.shared.applyFlat()
        appliedProposalID = nil
        appliedSongIdentifier = nil
    }

    func testProviderConnection() async throws {
        let managedAgent = await SongContentConfigurationStore.shared.agentConfiguration(.equalizer)
        if let managedAgent, !managedAgent.enabled { throw AIEqualizerError.modelUnavailable }
        let configuration = try await resolvedProviderConfiguration(usePublishedConfiguration: false)
        let bundledSystemPrompt = AIEqualizerPrompt.system(for: .tenBand)
        let text = try await client.generate(
            systemPrompt: managedAgent?.systemPrompt(fallback: bundledSystemPrompt) ?? bundledSystemPrompt,
            userPrompt: managedAgent?.userPrompt(fallback: AIEqualizerPrompt.connectivityTest)
                ?? AIEqualizerPrompt.connectivityTest,
            configuration: configuration,
            apiKey: providerStore.apiKey,
            minimumTimeout: managedAgent?.resolvedMinimumTimeoutSeconds ?? 0,
            options: managedAgent?.generationOptions ?? .standard
        )
        _ = try decodeModelOutput(from: text, expectedMode: .tenBand)
    }

    private func scheduleAutomaticAnalysis() {
        guard automaticConfigurationEnabled,
              let scheduledSong = PlayerManager.shared.currentSong,
              !scheduledSong.isAppleMusic else { return }
        let scheduledIdentifier = songIdentifier(scheduledSong)

        if appliedSongIdentifier == scheduledIdentifier,
           EQManager.shared.isAIManagedPresetActive {
            return
        }
        if activeAnalysisSongIdentifier == scheduledIdentifier, phase.isWorking {
            return
        }
        if scheduledAutomaticSongIdentifier == scheduledIdentifier,
           automaticTask != nil {
            return
        }

        automaticTask?.cancel()
        let scheduledRunID = UUID()
        scheduledAutomaticRunID = scheduledRunID
        scheduledAutomaticSongIdentifier = scheduledIdentifier
        AppLogger.debug(
            "[AIEqualizerAgent] Automatic analysis scheduled song=\(scheduledIdentifier)",
            step: "ai-tuning.scheduled"
        )
        automaticTask = Task { [weak self] in
            defer {
                if let self, self.scheduledAutomaticRunID == scheduledRunID {
                    self.automaticTask = nil
                    self.scheduledAutomaticRunID = nil
                    self.scheduledAutomaticSongIdentifier = nil
                }
            }

            do {
                try await Task.sleep(for: .milliseconds(280))
            } catch {
                return
            }
            guard let self, self.scheduledAutomaticRunID == scheduledRunID else { return }

            var isPlaybackReady = false
            for _ in 0..<400 {
                guard !Task.isCancelled,
                      self.automaticConfigurationEnabled,
                      self.scheduledAutomaticRunID == scheduledRunID,
                      PlayerManager.shared.currentSong.map({ self.songIdentifier($0) }) == scheduledIdentifier else {
                    return
                }
                if PlayerManager.shared.isPlaying,
                   !PlayerManager.shared.isLoading,
                   PlayerManager.shared.streamPlayer.state == .playing {
                    isPlaybackReady = true
                    break
                }
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return
                }
            }
            guard isPlaybackReady else {
                AppLogger.warning(
                    "[AIEqualizerAgent] Automatic analysis skipped because playback was not ready song=\(scheduledIdentifier)",
                    step: "ai-tuning.waiting-playback"
                )
                return
            }
            AppLogger.info(
                "[AIEqualizerAgent] Playback ready for automatic analysis song=\(scheduledIdentifier)",
                step: "ai-tuning.playback-ready"
            )
            do {
                try await Task.sleep(for: .milliseconds(420))
            } catch {
                return
            }
            guard !Task.isCancelled,
                  self.scheduledAutomaticRunID == scheduledRunID,
                  PlayerManager.shared.currentSong.map({ self.songIdentifier($0) }) == scheduledIdentifier,
                  PlayerManager.shared.isPlaying,
                  !PlayerManager.shared.isLoading else { return }
            await self.runAnalysis(trigger: .automatic)
        }
    }

    private func runAnalysis(
        trigger: AIEqualizerAnalysisTrigger = .manual,
        forceRegeneration: Bool = false
    ) async {
        guard let song = PlayerManager.shared.currentSong else {
            phase = .failed(AIEqualizerError.noSong.localizedDescription)
            return
        }
        guard !song.isAppleMusic else {
            phase = .failed(
                AIEqualizerError.protectedAudioUnsupported.localizedDescription
            )
            return
        }
        let identifier = songIdentifier(song)
        guard activeAnalysisSongIdentifier == nil else { return }
        let analysisRunID = UUID()
        activeAnalysisRunID = analysisRunID
        activeAnalysisSongIdentifier = identifier
        defer {
            if activeAnalysisRunID == analysisRunID {
                activeAnalysisRunID = nil
                activeAnalysisSongIdentifier = nil
                analysisTask = nil
                tuningStartedAt = nil
            }
        }

        let managedAgent = await SongContentConfigurationStore.shared.agentConfiguration(.equalizer)
        if let managedAgent, !managedAgent.enabled {
            phase = .failed(AIEqualizerError.modelUnavailable.localizedDescription)
            return
        }

        let requestedIntensity = tuningIntensity
        let requestedProfile = tuningProfile
        let graphicEQMode = EQManager.shared.graphicEQMode
        let deviceTuningTarget = AirPodsExperienceManager.currentAITuningTargetSnapshot()
        let outputIdentity = currentOutputIdentity()

        // Replaying a song restores its validated result before sampling. The
        // current spatial profile is the exception because earlier versions were
        // clamped to standard-profile spatial ranges and need one regeneration.
        if !forceRegeneration,
           let saved = proposalCache.latestReusable(
               for: identifier,
               outputIdentity: outputIdentity,
               graphicEQMode: graphicEQMode,
               tuningIntensity: requestedIntensity,
               tuningProfile: requestedProfile
           ) {
            let generatedAgentVersion = saved.proposal.agentVersion ?? "legacy"
            let requiresSpatialUpgrade = requestedProfile == .monoSpatialEnhancement
                && generatedAgentVersion != activePromptVersion
            if requiresSpatialUpgrade {
                AppLogger.info(
                    "[AIEqualizerAgent] Regenerating legacy spatial proposal song=\(identifier) proposal=\(saved.id.uuidString) generatedBy=\(generatedAgentVersion) currentAgent=\(activePromptVersion)",
                    step: "ai-tuning.spatial-upgrade"
                )
            } else {
                samplingRetryCount[identifier] = nil
                savedProposals = proposalCache.history(for: identifier)
                proposal = saved.proposal
                AppLogger.info(
                    "[AIEqualizerAgent] Reused saved proposal before analysis song=\(identifier) proposal=\(saved.id.uuidString) output=\(outputIdentity) generatedBy=\(generatedAgentVersion) currentAgent=\(activePromptVersion)",
                    step: "ai-tuning.saved-reuse"
                )
                apply(saved.proposal)
                return
            }
        }

        let configuration: AIProviderConfiguration
        do {
            configuration = try await resolvedProviderConfiguration()
        } catch {
            if isCurrentSong(song) {
                phase = .failed(error.localizedDescription)
            }
            return
        }
        guard isCurrentSong(song) else { return }
        let runStartedAt = Date()
        tuningStartedAt = runStartedAt
        let samplingDuration = resolvedSamplingDuration(for: song)
        let samplingDurationText = String(format: "%.1f", samplingDuration)
        AppLogger.info(
            "[AIEqualizerAgent] Analysis prepared songID=\(song.id) mode=\(samplingMode.rawValue) intensity=\(requestedIntensity.rawValue) profile=\(requestedProfile.rawValue) eqBands=\(graphicEQMode.bandCount) target=\(samplingDurationText)s output=\(EQManager.shared.currentOutputName) protocol=\(configuration.wireProtocol.rawValue) model=\(configuration.resolvedModel)",
            step: "ai-tuning.prepare"
        )
        let audioVariant = audioVariantIdentity(for: song)
        let learningRevision = adaptiveLearningEnabled ? learningStore.revision : 0
        let reusableMeasuredFeatures: AIEqualizerAudioFeatures?
        if forceRegeneration {
            reusableMeasuredFeatures = nil
        } else {
            reusableMeasuredFeatures = measurementStore.value(
                songIdentifier: identifier,
                audioVariant: audioVariant,
                outputIdentity: outputIdentity,
                graphicEQMode: graphicEQMode
            )
            if let reusableMeasuredFeatures {
                measuredFeatures = reusableMeasuredFeatures
            }
        }
        let deviceTuningIdentity = deviceTuningTarget?.identifier ?? "device-baseline:none"
        let cacheKey = "\(managedAgent?.promptVersion ?? AIEqualizerPrompt.version)|mono-agent-v5|learning:\(learningRevision)|\(graphicEQMode.rawValue)|\(song.musicSource.rawValue)|\(song.id)|\(audioVariant)|\(configuration.wireProtocol.rawValue)|\(configuration.resolvedModel)|\(outputIdentity)|\(deviceTuningIdentity)|\(samplingMode.rawValue)|\(Int(samplingDuration.rounded()))|\(requestedIntensity.rawValue)|\(requestedProfile.rawValue)"
        if !forceRegeneration, let cached = proposalCache.value(for: cacheKey) {
            samplingRetryCount[identifier] = nil
            if proposalCache.shouldRecord(
                cached,
                songIdentifier: identifier,
                outputIdentity: outputIdentity
            ) {
                proposalCache.record(
                    cached,
                    songIdentifier: identifier,
                    outputIdentity: outputIdentity
                )
            }
            savedProposals = proposalCache.history(for: identifier)
            AppLogger.info(
                "[AIEqualizerAgent] Applied cached proposal song=\(identifier) output=\(outputIdentity)",
                step: "ai-tuning.cache-hit"
            )
            recordProfileName(cached.profileName)
            proposal = cached
            apply(cached)
            return
        }
        do {
            let samplingStartedAt = Date()
            let features: AIEqualizerAudioFeatures
            let samplingElapsed: TimeInterval
            if let reusableMeasuredFeatures {
                samplingStage = .finalizing
                phase = .sampling(progress: 1)
                features = reusableMeasuredFeatures
                samplingElapsed = 0
                AppLogger.info(
                    "[AIEqualizerAgent] Reused measured features song=\(identifier) variant=\(audioVariant) output=\(outputIdentity) mode=\(graphicEQMode.rawValue) frames=\(features.frameCount)",
                    step: "ai-tuning.measurement-reuse"
                )
            } else {
                samplingStage = .preparing
                phase = .sampling(progress: 0)
                features = try await sampler.sample(
                    song: song,
                    duration: samplingDuration,
                    graphicEQMode: graphicEQMode
                ) { [weak self] value, stage in
                    self?.samplingStage = stage
                    self?.phase = .sampling(progress: value)
                }
                samplingElapsed = Date().timeIntervalSince(samplingStartedAt)
            }
            try Task.checkCancellation()
            guard isCurrentSong(song), EQManager.shared.graphicEQMode == graphicEQMode else {
                throw AIEqualizerError.noSong
            }

            if reusableMeasuredFeatures == nil {
                measurementStore.set(
                    features,
                    songIdentifier: identifier,
                    audioVariant: audioVariant,
                    outputIdentity: outputIdentity
                )
                AppLogger.success(
                    "[AIEqualizerAgent] Measurement persisted song=\(identifier) variant=\(audioVariant) output=\(outputIdentity) mode=\(graphicEQMode.rawValue) frames=\(features.frameCount)",
                    step: "ai-tuning.measurement-saved"
                )
            }
            measuredFeatures = features
            let learningContext = adaptiveLearningEnabled
                ? learningStore.context(
                    for: features,
                    outputIdentity: outputIdentity
                )
                : nil
            let generation = try await generateValidatedOutputWithRetry(
                features: features,
                configuration: configuration,
                requestedIntensity: requestedIntensity,
                requestedProfile: requestedProfile,
                graphicEQMode: graphicEQMode,
                song: song,
                learningContext: learningContext,
                deviceTuningTarget: deviceTuningTarget,
                managedAgent: managedAgent
            )
            let output = generation.output
            let generationElapsed = generation.elapsed
            let applyingStartedAt = Date()
            generationStage = .finalizing
            var result = AIEqualizerProposal(
                songID: song.id,
                output: output,
                features: features,
                provider: configuration.wireProtocol,
                model: configuration.resolvedModel,
                agentVersion: managedAgent?.promptVersion ?? AIEqualizerPrompt.version,
                tuningIntensity: requestedIntensity,
                tuningProfile: requestedProfile,
                avoidingProfileNames: Set(recentProfileNames),
                learningContext: learningContext,
                deviceTuningTarget: deviceTuningTarget
            )
            proposal = result
            apply(result)
            let applyingElapsed = Date().timeIntervalSince(applyingStartedAt)
            let timing = AIEqualizerTiming(
                total: Date().timeIntervalSince(runStartedAt),
                sampling: samplingElapsed,
                generation: generationElapsed,
                applying: applyingElapsed,
                completedAt: Date()
            )
            result.timing = timing
            recordProfileName(result.profileName)
            proposalCache.set(result, for: cacheKey)
            if proposalCache.shouldRecord(
                result,
                songIdentifier: identifier,
                outputIdentity: outputIdentity
            ) {
                proposalCache.record(
                    result,
                    songIdentifier: identifier,
                    outputIdentity: outputIdentity
                )
            } else {
                AppLogger.info(
                    "[AIEqualizerAgent] Skipped history save because tuning change was below threshold song=\(identifier)",
                    step: "ai-tuning.saved-skip"
                )
            }
            savedProposals = proposalCache.history(for: identifier)
            samplingRetryCount[identifier] = nil
            proposal = result
            AppLogger.success(
                "[AIEqualizerAgent] Analysis timing songID=\(song.id) total=\(String(format: "%.2f", timing.total))s sampling=\(String(format: "%.2f", timing.sampling))s generation=\(String(format: "%.2f", timing.generation))s applying=\(String(format: "%.2f", timing.applying))s intensity=\(requestedIntensity.rawValue)",
                step: "ai-tuning.timing"
            )
        } catch is CancellationError {
            guard activeAnalysisRunID == analysisRunID else { return }
            let elapsed = Date().timeIntervalSince(runStartedAt)
            AppLogger.info(
                "[AIEqualizerAgent] Analysis cancelled songID=\(song.id) phase=\(String(describing: phase)) elapsed=\(String(format: "%.2f", elapsed))s",
                step: "ai-tuning.cancelled"
            )
            if isCurrentSong(song) {
                if measuredFeatures == nil {
                    measuredFeatures = restoredMeasurement(
                        for: song,
                        graphicEQMode: graphicEQMode
                    )
                }
                phase = .idle
            }
        } catch {
            guard activeAnalysisRunID == analysisRunID else { return }
            let elapsed = Date().timeIntervalSince(runStartedAt)
            let failurePositionText = String(format: "%.1f", PlayerManager.shared.currentTime)
            let failureDurationText = String(format: "%.1f", PlayerManager.shared.duration)
            AppLogger.error(
                "[AIEqualizerAgent] Analysis failed songID=\(song.id) phase=\(String(describing: phase)) mode=\(samplingMode.rawValue) intensity=\(requestedIntensity.rawValue) elapsed=\(String(format: "%.2f", elapsed))s playerState=\(String(describing: PlayerManager.shared.streamPlayer.state)) appPlaying=\(PlayerManager.shared.isPlaying) loading=\(PlayerManager.shared.isLoading) position=\(failurePositionText)/\(failureDurationText) error=\(error.localizedDescription)",
                step: "ai-tuning.failed"
            )
            if isCurrentSong(song) {
                if measuredFeatures == nil {
                    measuredFeatures = restoredMeasurement(
                        for: song,
                        graphicEQMode: graphicEQMode
                    )
                }
                phase = .failed(error.localizedDescription)
                scheduleSamplingRetryIfNeeded(for: identifier, error: error, trigger: trigger)
            }
        }
    }

    private func scheduleSamplingRetryIfNeeded(
        for identifier: String,
        error: Error,
        trigger: AIEqualizerAnalysisTrigger
    ) {
        if trigger == .automatic, !automaticConfigurationEnabled { return }
        guard let aiError = error as? AIEqualizerError else { return }
        switch aiError {
        case .sampleUnavailable, .playbackRequired:
            break
        default:
            return
        }

        let attempt = (samplingRetryCount[identifier] ?? 0) + 1
        guard attempt <= Self.maxSamplingRetryAttempts else {
            AppLogger.warning(
                "[AIEqualizerAgent] Sampling retries exhausted song=\(identifier) attempts=\(Self.maxSamplingRetryAttempts)",
                step: "ai-tuning.retry-exhausted"
            )
            return
        }
        samplingRetryCount[identifier] = attempt
        AppLogger.warning(
            "[AIEqualizerAgent] Sampling retry scheduled song=\(identifier) trigger=\(trigger.logName) attempt=\(attempt)/\(Self.maxSamplingRetryAttempts)",
            step: "ai-tuning.retry-scheduled"
        )
        automaticRetryTask?.cancel()
        automaticRetryTask = Task { [weak self] in
            defer {
                if let self,
                   self.samplingRetryCount[identifier] == attempt {
                    self.automaticRetryTask = nil
                }
            }
            do {
                try await Task.sleep(for: .seconds(Double(attempt * 2)))
            } catch {
                return
            }
            guard let self,
                  PlayerManager.shared.currentSong.map({ self.songIdentifier($0) }) == identifier else {
                return
            }
            if trigger == .automatic, !self.automaticConfigurationEnabled { return }

            // Sampling must never force playback. Wait for the existing player to
            // become usable so a transient audio-route or decoder interruption can
            // recover without producing another false "no usable audio" result.
            for _ in 0..<120 {
                guard !Task.isCancelled,
                      PlayerManager.shared.currentSong.map({ self.songIdentifier($0) }) == identifier else {
                    return
                }
                if PlayerManager.shared.isPlaying,
                   !PlayerManager.shared.isLoading,
                   PlayerManager.shared.streamPlayer.state == .playing {
                    if trigger == .automatic {
                        self.scheduleAutomaticAnalysis()
                    } else {
                        self.analysisTask?.cancel()
                        self.analysisTask = Task { [weak self] in
                            await self?.runAnalysis(trigger: .manual, forceRegeneration: true)
                        }
                    }
                    return
                }
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
            }
            AppLogger.warning(
                "[AIEqualizerAgent] Sampling retry timed out waiting for playback song=\(identifier) trigger=\(trigger.logName)",
                step: "ai-tuning.retry-wait-timeout"
            )
        }
    }

    private func generateValidatedOutputWithRetry(
        features: AIEqualizerAudioFeatures,
        configuration: AIProviderConfiguration,
        requestedIntensity: AIEqualizerTuningIntensity,
        requestedProfile: AIEqualizerTuningProfile,
        graphicEQMode: GraphicEQMode,
        song: Song,
        learningContext: AIEqualizerLearningContext?,
        deviceTuningTarget: AIEqualizerDeviceTuningTarget?,
        managedAgent: AppAgentConfiguration?
    ) async throws -> (output: AIEqualizerModelOutput, elapsed: TimeInterval) {
        let startedAt = Date()
        generationStartedAt = startedAt
        let bundledUserPrompt = try AIEqualizerPrompt.userPrompt(
            features: features,
            tuningIntensity: requestedIntensity,
            tuningProfile: requestedProfile,
            avoidingProfileNames: recentProfileNames,
            learningContext: learningContext
        )
        let configuredUserPrompt = managedAgent?.userPrompt(fallback: bundledUserPrompt) ?? bundledUserPrompt
        let userPrompt = try AIEqualizerPrompt.appendingDeviceTuningTarget(
            deviceTuningTarget,
            to: configuredUserPrompt
        )
        let bundledSystemPrompt = AIEqualizerPrompt.system(for: graphicEQMode)
        let systemPrompt = managedAgent?.systemPrompt(
            fallback: bundledSystemPrompt,
            secondaryFallback: graphicEQMode == .thirtyTwoBand ? bundledSystemPrompt : nil
        ) ?? bundledSystemPrompt
        let maximumAttempts = managedAgent?.resolvedMaxAttempts(
            fallback: Self.maxGenerationRetryAttempts
        ) ?? Self.maxGenerationRetryAttempts

        for attempt in 1...maximumAttempts {
            try Task.checkCancellation()
            guard isCurrentSong(song), EQManager.shared.graphicEQMode == graphicEQMode else {
                throw AIEqualizerError.noSong
            }

            generationStage = .preparing
            phase = .requesting
            var reservation: Date?
            do {
                // Reserve every actual request. Quota and frequency errors are
                // intentionally not retried by the classifier below.
                reservation = try usageLimiter.reserveRequest(limits: providerStore.usageLimits)
                generationStage = .generating
                let response = try await client.generate(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    configuration: configuration,
                    apiKey: providerStore.requestAPIKey,
                    minimumTimeout: max(120, managedAgent?.resolvedMinimumTimeoutSeconds ?? 0),
                    options: managedAgent?.generationOptions ?? .standard
                )
                try Task.checkCancellation()
                guard isCurrentSong(song), EQManager.shared.graphicEQMode == graphicEQMode else {
                    throw AIEqualizerError.noSong
                }
                AppLogger.debug(
                    "[AIEqualizerAgent] Model response received songID=\(song.id) attempt=\(attempt)/\(maximumAttempts) characters=\(response.count) expectedBands=\(graphicEQMode.bandCount)",
                    step: "ai-tuning.response-received"
                )
                generationStage = .validating
                let output = try decodeModelOutput(from: response, expectedMode: graphicEQMode)
                return (output, Date().timeIntervalSince(startedAt))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if let reservation, AIUsageLimiter.shouldRefundReservation(for: error) {
                    usageLimiter.releaseReservation(reservation)
                }
                guard attempt < maximumAttempts,
                      AIAgentRuntimePolicy.shouldRetry(error) else {
                    throw error
                }
                let delay = generationRetryDelay(
                    for: attempt,
                    minimumRequestInterval: providerStore.usageLimits.minimumRequestInterval
                )
                AppLogger.warning(
                    "[AIEqualizerAgent] Generation retry scheduled song=\(song.id) attempt=\(attempt + 1)/\(maximumAttempts) delay=\(String(format: "%.1f", delay))s error=\(error.localizedDescription)",
                    step: "ai-tuning.generation-retry"
                )
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    throw CancellationError()
                }
            }
        }

        throw AIEqualizerError.invalidResponse
    }

    private func generationRetryDelay(
        for attempt: Int,
        minimumRequestInterval: TimeInterval
    ) -> TimeInterval {
        AIAgentRuntimePolicy.retryDelay(
            after: attempt,
            minimumRequestInterval: minimumRequestInterval
        )
    }

    @discardableResult
    private func apply(_ proposal: AIEqualizerProposal, isManualAction: Bool = false) -> Bool {
        let currentSongID = PlayerManager.shared.currentSong?.id
        let currentMode = EQManager.shared.graphicEQMode
        guard currentSongID == proposal.songID, currentMode == proposal.graphicEQMode else {
            // 静默丢弃会让 UI 停在“已生成/已应用”的假象上，DSP 却没动。
            // 手动操作给出明确失败反馈；自动流程至少留痕并收敛工作状态。
            AppLogger.warning(
                "[AIEqualizerAgent] Apply skipped currentSong=\(currentSongID.map { String($0) } ?? "none") proposalSong=\(proposal.songID) currentMode=\(currentMode.rawValue) proposalMode=\(proposal.graphicEQMode.rawValue) manual=\(isManualAction)",
                step: "ai-tuning.apply-skipped"
            )
            if isManualAction {
                phase = .failed(String(localized: "ai_tuning_apply_context_changed"))
                HapticManager.shared.warning()
            } else if phase.isWorking {
                phase = .idle
            }
            return false
        }
        phase = .applying
        let manager = EQManager.shared
        let resolvedSpatial = MonoNextSuiteManager.shared.resolvedSpatialForTuningProposal(proposal)
        manager.applyAIConfiguration(proposal, spatialOverride: resolvedSpatial)
        let effects = proposal.effects
        let professional = proposal.professional
        let enhance = proposal.enhance
        let appliedAudioEffects = PlayerManager.shared.audioEffects
        let outputGainDB = PlayerManager.shared.audioRepair.outputGainDB
        let perceptualMakeupDB = PlayerManager.shared.audioRepair.perceptualMakeupDB
        AppLogger.success(
            "[AIEqualizerAgent] Applied songID=\(proposal.songID) profile=\(proposal.profileName) tuningProfile=\(proposal.resolvedTuningProfile.rawValue) bands=\(proposal.graphicEQMode.bandCount) preamp=\(String(format: "%.2f", proposal.preampDB))dB surround=\(String(format: "%.3f", appliedAudioEffects.surroundLevel)) reverb=\(String(format: "%.3f", appliedAudioEffects.reverbLevel)) width=\(String(format: "%.3f", appliedAudioEffects.stereoWidth)) outputGain=\(String(format: "%.2f", outputGainDB))dB perceptualMakeup=\(String(format: "%.2f", perceptualMakeupDB))dB nativeEnhance=\(enhance.isEnabled) transient=\(String(format: "%.3f", enhance.transientAttack)) vocal=\(String(format: "%.3f", enhance.vocalFocus)) air=\(String(format: "%.3f", enhance.airAmount)) stage=\(String(format: "%.3f", enhance.stageWidth)) micro=\(String(format: "%.3f", enhance.microDynamics)) dynamicEQ=\(professional.dynamicEQ.enabled ? professional.dynamicEQ.bands.count : 0) multiband=\(professional.multiband.enabled) parametricEQ=\(professional.parametricEQ.enabled ? professional.parametricEQ.bands.count : 0) loudnorm=\(effects.loudnessNormalizationEnabled) compressor=\(effects.compressorEnabled) subboost=\(effects.subboostEnabled) virtualBass=\(effects.virtualBassEnabled) bs2b=\(effects.bs2bEnabled) crossfeed=\(effects.crossfeedEnabled) haas=\(effects.haasEnabled) exciter=\(effects.exciterEnabled) softclip=\(effects.softclipEnabled) limiter=\(effects.finalLimiterEnabled) ceiling=\(String(format: "%.2f", effects.finalLimiterCeilingDB))dBFS",
            step: "ai-tuning.applied"
        )
        appliedProposalID = proposal.id
        appliedSongIdentifier = PlayerManager.shared.currentSong.map { songIdentifier($0) }
        beginLearningSession(for: proposal)
        phase = .ready
        HapticManager.shared.success()
        return true
    }

    private func beginLearningSession(for proposal: AIEqualizerProposal) {
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

    private func updateLearningPlaybackPosition(_ position: Double) {
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

    private func finalizeRetainedLearningSession() {
        guard adaptiveLearningEnabled,
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

    private func recordImplicitFeedbackIfNeeded(_ feedback: AIEqualizerLearningFeedback) {
        guard adaptiveLearningEnabled,
              let session = activeLearningSession,
              appliedProposalID == session.proposal.id else { return }
        persistLearningFeedback(feedback, session: session)
        activeLearningSession?.hasExplicitFeedback = true
        currentLearningFeedback = feedback
    }

    private func recordFeedbackIfPossible(_ feedback: AIEqualizerLearningFeedback) {
        guard adaptiveLearningEnabled else { return }
        let session: AIEqualizerActiveLearningSession
        if let activeLearningSession,
           activeLearningSession.proposal.id == proposal?.id {
            session = activeLearningSession
        } else if let proposal,
                  let song = PlayerManager.shared.currentSong {
            session = AIEqualizerActiveLearningSession(
                proposal: proposal,
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

    private func persistLearningFeedback(
        _ feedback: AIEqualizerLearningFeedback,
        session: AIEqualizerActiveLearningSession
    ) {
        learningStore.record(feedback: feedback, session: session)
        learningEvidenceCount = learningStore.evidenceCount
        let listenedText = String(format: "%.1f", session.listenedSeconds)
        AppLogger.info(
            "[AIEqualizerAgent] Learning feedback recorded feedback=\(feedback.rawValue) proposal=\(session.proposal.id.uuidString) listened=\(listenedText)s revision=\(learningStore.revision) evidence=\(learningEvidenceCount)",
            step: "ai-tuning.learning-feedback"
        )
    }

    private func recordProfileName(_ name: String) {
        recentProfileNames.removeAll { $0 == name }
        recentProfileNames.append(name)
        recentProfileNames = Array(recentProfileNames.suffix(16))
        UserDefaults.standard.set(recentProfileNames, forKey: Self.recentProfileNamesKey)
    }

    private func songIdentifier(_ song: Song) -> String {
        "\(song.musicSource.rawValue):\(song.id)"
    }

    private func currentOutputIdentity() -> String {
        let manager = EQManager.shared
        let baseIdentity = manager.currentOutputName.isEmpty
            ? manager.currentOutputKind.rawValue
            : "\(manager.currentOutputKind.rawValue):\(manager.currentOutputName)"
        guard let target = AirPodsExperienceManager.currentAITuningTargetSnapshot() else {
            return baseIdentity
        }
        return "\(baseIdentity)|\(target.identifier)"
    }

    private func restoredMeasurement(
        for song: Song,
        graphicEQMode: GraphicEQMode? = nil
    ) -> AIEqualizerAudioFeatures? {
        measurementStore.value(
            songIdentifier: songIdentifier(song),
            audioVariant: audioVariantIdentity(for: song),
            outputIdentity: currentOutputIdentity(),
            graphicEQMode: graphicEQMode ?? EQManager.shared.graphicEQMode
        )
    }

    private func audioVariantIdentity(for song: Song) -> String {
        let player = PlayerManager.shared
        var components = [
            song.musicSource.rawValue,
            "duration:\(song.dt ?? 0)"
        ]
        if let qqMid = song.qqMid, !qqMid.isEmpty {
            components.append("qq:\(qqMid)")
        }
        if let trackID = song.qishuiTrackId {
            components.append("qishui:\(trackID)")
        }
        if let localURL = song.localFileURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path) {
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            components.append("local:\(localURL.lastPathComponent):\(size):\(Int(modified))")
        } else {
            let quality = (player.qualityInfoText ?? player.qualityButtonText)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !quality.isEmpty {
                components.append("quality:\(quality)")
            }
            if let input = player.currentPlayingURL,
               let url = URL(string: input),
               !url.lastPathComponent.isEmpty {
                components.append("asset:\(String(url.lastPathComponent.prefix(120)))")
            }
        }
        return components
            .joined(separator: "|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func isCurrentSong(_ song: Song) -> Bool {
        guard let current = PlayerManager.shared.currentSong else { return false }
        return current.id == song.id && current.musicSource == song.musicSource
    }

    private func resolvedSamplingDuration(for song: Song) -> TimeInterval {
        let trackDuration = max(PlayerManager.shared.duration, Double(song.dt ?? 0) / 1_000)
        let requested: TimeInterval
        switch samplingMode {
        case .fast:
            requested = 15
        case .deep:
            requested = 60
        case .custom:
            requested = min(120, max(10, customSamplingDuration))
        case .smart:
            switch trackDuration {
            case 0..<75: requested = 18
            case 75..<180: requested = 28
            case 360...: requested = 45
            default: requested = 36
            }
        }

        let remaining = PlayerManager.shared.duration - PlayerManager.shared.currentTime
        let availableDuration = remaining > 0 ? min(requested, max(8, remaining - 2)) : requested
        return UIScreen.main.isCaptured
            ? min(20, availableDuration)
            : availableDuration
    }

    private func resolvedProviderConfiguration(
        usePublishedConfiguration: Bool = true
    ) async throws -> AIProviderConfiguration {
        if usePublishedConfiguration {
            providerStore.refreshRemoteConfigurationInBackgroundIfNeeded()
        }
        var configuration = usePublishedConfiguration
            ? providerStore.requestConfiguration
            : providerStore.configuration
        let apiKey = usePublishedConfiguration ? providerStore.requestAPIKey : providerStore.apiKey
        if configuration.wireProtocol.requiresAPIKey,
           apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AIEqualizerError.missingAPIKey
        }

        let configuredModel = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard configuredModel.isEmpty,
              configuration.wireProtocol != .appleIntelligence else {
            return configuration
        }

        let modelCacheKey = providerModelCacheKey(configuration: configuration, apiKey: apiKey)
        if let cachedModel = discoveredProviderModels[modelCacheKey] {
            configuration.model = cachedModel
            AppLogger.info(
                "[AIEqualizerAgent] Reused discovered provider model protocol=\(configuration.wireProtocol.rawValue) model=\(cachedModel)",
                step: "ai-tuning.model-cache"
            )
            if usePublishedConfiguration, providerStore.isUsingRemoteConfiguration {
                return configuration
            }
            providerStore.model = cachedModel
            return providerStore.configuration
        }

        let models = try await client.fetchModels(
            configuration: configuration,
            apiKey: apiKey
        )
        let preferred = configuration.wireProtocol.defaultModel
        guard let selected = models.contains(preferred) ? preferred : models.first else {
            throw AIEqualizerError.modelUnavailable
        }
        discoveredProviderModels[modelCacheKey] = selected
        AppLogger.info(
            "[AIEqualizerAgent] Cached discovered provider model protocol=\(configuration.wireProtocol.rawValue) model=\(selected)",
            step: "ai-tuning.model-cache"
        )
        if usePublishedConfiguration, providerStore.isUsingRemoteConfiguration {
            configuration.model = selected
            return configuration
        }
        providerStore.model = selected
        return providerStore.configuration
    }

    private func providerModelCacheKey(
        configuration: AIProviderConfiguration,
        apiKey: String
    ) -> String {
        [
            configuration.wireProtocol.rawValue,
            configuration.resolvedBaseURL,
            configuration.modelDiscoveryURL,
            String(apiKey.hashValue)
        ].joined(separator: "|")
    }

    private func decodeModelOutput(
        from rawText: String,
        expectedMode: GraphicEQMode
    ) throws -> AIEqualizerModelOutput {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```JSON", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let containsClosingBrace = text.lastIndex(of: "}") != nil
        if let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}"), first <= last {
            text = String(text[first...last])
        }

        guard let data = text.data(using: .utf8) else {
            AppLogger.error(
                "[AIEqualizerAgent] Model response is not UTF-8 characters=\(text.count)",
                step: "ai-tuning.response-invalid"
            )
            throw AIEqualizerError.invalidResponse
        }

        let output: AIEqualizerModelOutput
        do {
            output = try JSONDecoder().decode(AIEqualizerModelOutput.self, from: data)
        } catch {
            let preview = Self.responsePreview(text)
            AppLogger.error(
                "[AIEqualizerAgent] Model JSON decode failed characters=\(text.count) closingBrace=\(containsClosingBrace) expectedBands=\(expectedMode.bandCount) decoding=\(Self.decodingErrorDescription(error)) response=\(preview)",
                step: "ai-tuning.response-invalid"
            )
            throw AIEqualizerError.invalidResponse
        }

        guard output.gains.count == expectedMode.bandCount else {
            AppLogger.error(
                "[AIEqualizerAgent] Model returned wrong EQ band count expected=\(expectedMode.bandCount) actual=\(output.gains.count)",
                step: "ai-tuning.response-invalid"
            )
            throw AIEqualizerError.invalidResponse
        }
        guard output.gains.allSatisfy({ $0.isFinite }),
              output.preampDB.isFinite,
              output.confidence.isFinite else {
            AppLogger.error(
                "[AIEqualizerAgent] Model returned non-finite tuning parameters bands=\(output.gains.count) preamp=\(output.preampDB) confidence=\(output.confidence)",
                step: "ai-tuning.response-invalid"
            )
            throw AIEqualizerError.invalidResponse
        }
        return output
    }

    private static func responsePreview(_ text: String) -> String {
        let compact = text.replacingOccurrences(of: "\n", with: " ")
        guard compact.count > 1_200 else { return compact }
        return "\(compact.prefix(800)) … \(compact.suffix(400))"
    }

    private static func decodingErrorDescription(_ error: Error) -> String {
        guard let error = error as? DecodingError else { return error.localizedDescription }
        switch error {
        case let .keyNotFound(key, context):
            return "missing key \(key.stringValue) at \(codingPath(context.codingPath))"
        case let .typeMismatch(type, context):
            return "type mismatch \(type) at \(codingPath(context.codingPath)): \(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "missing value \(type) at \(codingPath(context.codingPath)): \(context.debugDescription)"
        case let .dataCorrupted(context):
            return "corrupted data at \(codingPath(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func codingPath(_ path: [CodingKey]) -> String {
        let value = path.map(\.stringValue).joined(separator: ".")
        return value.isEmpty ? "<root>" : value
    }
}

/// A malformed or obsolete persisted entry must not make sibling entries
/// undecodable. The durable proposal model supplies migration defaults; this
/// wrapper contains damage when an individual record is genuinely corrupt.
private struct LossyDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

@MainActor
private final class AIEqualizerProposalCacheStore {
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

    func value(for key: String, now: Date = Date()) -> AIEqualizerProposal? {
        guard let value = values[key] else { return nil }
        guard now.timeIntervalSince(value.createdAt) <= Self.maximumAge else {
            values.removeValue(forKey: key)
            persist()
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

    func latestReusable(
        for songIdentifier: String,
        outputIdentity: String,
        graphicEQMode: GraphicEQMode,
        tuningIntensity: AIEqualizerTuningIntensity,
        tuningProfile: AIEqualizerTuningProfile
    ) -> AIEqualizerSavedProposal? {
        history(for: songIdentifier).first {
            $0.outputIdentity == outputIdentity
                && $0.proposal.graphicEQMode == graphicEQMode
                && ($0.proposal.tuningIntensity ?? .smart) == tuningIntensity
                && ($0.proposal.tuningProfile ?? .standard) == tuningProfile
        }
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

private struct AIEqualizerMeasuredFeatureRecord: Codable, Sendable {
    let schemaVersion: Int
    let songIdentifier: String
    let audioVariant: String
    let outputIdentity: String
    let graphicEQMode: GraphicEQMode
    let capturedAt: Date
    let features: AIEqualizerAudioFeatures

    var storageKey: String {
        "\(schemaVersion)|\(songIdentifier)|\(audioVariant)|\(outputIdentity)|\(graphicEQMode.rawValue)"
    }
}

@MainActor
private final class AIEqualizerMeasurementStore {
    private static let schemaVersion = 3
    private static let fileName = "AIEqualizerMeasurements-v3.json"
    private static let maximumEntries = 2_048

    private let storageURL: URL?
    private var records: [String: AIEqualizerMeasuredFeatureRecord]

    init() {
        storageURL = Self.makeStorageURL()
        if let storageURL,
           let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(
               [String: LossyDecodable<AIEqualizerMeasuredFeatureRecord>].self,
               from: data
           ) {
            records = decoded.compactMapValues(\.value)
        } else {
            records = [:]
        }
        removeInvalidRecords(persistChanges: true)
    }

    func value(
        songIdentifier: String,
        audioVariant: String,
        outputIdentity: String,
        graphicEQMode: GraphicEQMode
    ) -> AIEqualizerAudioFeatures? {
        removeInvalidRecords(persistChanges: true)
        let compatible = records.values.filter {
            $0.schemaVersion == Self.schemaVersion
                && $0.songIdentifier == songIdentifier
                && $0.outputIdentity == outputIdentity
                && $0.graphicEQMode == graphicEQMode
        }
        let exact = compatible
            .filter { $0.audioVariant == audioVariant }
            .max { $0.capturedAt < $1.capturedAt }
        let selected = exact ?? compatible.max { $0.capturedAt < $1.capturedAt }
        guard let selected else { return nil }
        AppLogger.info(
            "[AIEqualizerAgent] Measurement restored song=\(songIdentifier) exactVariant=\(exact != nil) output=\(outputIdentity) mode=\(graphicEQMode.rawValue) capturedAt=\(selected.capturedAt.timeIntervalSince1970)",
            step: "ai-tuning.measurement-restored"
        )
        return selected.features
    }

    func set(
        _ features: AIEqualizerAudioFeatures,
        songIdentifier: String,
        audioVariant: String,
        outputIdentity: String,
        now: Date = Date()
    ) {
        let record = AIEqualizerMeasuredFeatureRecord(
            schemaVersion: Self.schemaVersion,
            songIdentifier: songIdentifier,
            audioVariant: audioVariant,
            outputIdentity: outputIdentity,
            graphicEQMode: features.graphicEQMode,
            capturedAt: now,
            features: features
        )
        records[record.storageKey] = record
        removeInvalidRecords(persistChanges: false)
        if records.count > Self.maximumEntries {
            records = Dictionary(
                uniqueKeysWithValues: records.values
                    .sorted { $0.capturedAt > $1.capturedAt }
                    .prefix(Self.maximumEntries)
                    .map { ($0.storageKey, $0) }
            )
        }
        persist()
    }

    private func removeInvalidRecords(persistChanges: Bool) {
        let previousCount = records.count
        records = records.filter {
            $0.value.schemaVersion == Self.schemaVersion
        }
        if records.count > Self.maximumEntries {
            records = Dictionary(
                uniqueKeysWithValues: records.values
                    .sorted { $0.capturedAt > $1.capturedAt }
                    .prefix(Self.maximumEntries)
                    .map { ($0.storageKey, $0) }
            )
        }
        if persistChanges, records.count != previousCount {
            persist()
        }
    }

    private func persist() {
        guard let storageURL else {
            AppLogger.error(
                "[AIEqualizerAgent] Measurement persistence skipped because storage URL is unavailable",
                step: "ai-tuning.measurement-save-failed"
            )
            return
        }
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            AppLogger.error(
                "[AIEqualizerAgent] Measurement persistence failed entries=\(records.count) error=\(error.localizedDescription)",
                step: "ai-tuning.measurement-save-failed"
            )
        }
    }

    private static func makeStorageURL() -> URL? {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let directory = applicationSupport.appendingPathComponent(
            "Mono",
            isDirectory: true
        )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory.appendingPathComponent(fileName, isDirectory: false)
        } catch {
            AppLogger.error(
                "[AIEqualizerAgent] Measurement storage directory unavailable error=\(error.localizedDescription)",
                step: "ai-tuning.measurement-storage-failed"
            )
            return nil
        }
    }
}

private struct AIEqualizerActiveLearningSession {
    let proposal: AIEqualizerProposal
    let songIdentifier: String
    let artist: String
    let outputIdentity: String
    let outputKind: String
    let genreHints: [String]
    let instrumentHints: [String]
    let startedAt: Date
    let trackDuration: TimeInterval
    var lastPosition: TimeInterval
    var listenedSeconds: TimeInterval
    var hasExplicitFeedback: Bool
}

private struct AIEqualizerLearningEpisode: Codable, Sendable {
    let schemaVersion: Int
    let proposalID: UUID
    let songIdentifier: String
    let artist: String
    let outputIdentity: String
    let outputKind: String
    let graphicEQMode: GraphicEQMode
    let genreHints: [String]
    let instrumentHints: [String]
    let gains: [Float]
    let bassGain: Float
    let trebleGain: Float
    let surroundLevel: Float
    let reverbLevel: Float
    let stereoWidth: Float
    let processingIntensity: Float
    let feedback: AIEqualizerLearningFeedback
    let listenedSeconds: TimeInterval
    let recordedAt: Date
}

private struct AIEqualizerLearningArchive: Codable, Sendable {
    var schemaVersion: Int
    var revision: Int
    var episodes: [AIEqualizerLearningEpisode]
}

@MainActor
private final class AIEqualizerLearningStore {
    private static let schemaVersion = 1
    private static let fileName = "MonoAudioAgentLearning-v1.json"
    private static let maximumEntries = 320
    private static let maximumAge: TimeInterval = 365 * 24 * 60 * 60

    private let storageURL: URL?
    private var archive: AIEqualizerLearningArchive

    var revision: Int { archive.revision }
    var evidenceCount: Int { archive.episodes.count }

    init() {
        storageURL = Self.makeStorageURL()
        if let storageURL,
           let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(AIEqualizerLearningArchive.self, from: data),
           decoded.schemaVersion == Self.schemaVersion {
            archive = decoded
        } else {
            archive = AIEqualizerLearningArchive(
                schemaVersion: Self.schemaVersion,
                revision: 1,
                episodes: []
            )
        }
        removeExpiredEpisodes()
    }

    func feedback(for proposalID: UUID) -> AIEqualizerLearningFeedback? {
        archive.episodes
            .filter { $0.proposalID == proposalID }
            .max { $0.recordedAt < $1.recordedAt }?
            .feedback
    }

    func record(
        feedback: AIEqualizerLearningFeedback,
        session: AIEqualizerActiveLearningSession,
        now: Date = Date()
    ) {
        archive.episodes.removeAll { $0.proposalID == session.proposal.id }
        archive.episodes.append(
            AIEqualizerLearningEpisode(
                schemaVersion: Self.schemaVersion,
                proposalID: session.proposal.id,
                songIdentifier: session.songIdentifier,
                artist: session.artist,
                outputIdentity: session.outputIdentity,
                outputKind: session.outputKind,
                graphicEQMode: session.proposal.graphicEQMode,
                genreHints: session.genreHints,
                instrumentHints: session.instrumentHints,
                gains: session.proposal.gains,
                bassGain: session.proposal.tone.bassGain,
                trebleGain: session.proposal.tone.trebleGain,
                surroundLevel: session.proposal.spatial.surroundLevel,
                reverbLevel: session.proposal.spatial.reverbLevel,
                stereoWidth: session.proposal.spatial.stereoWidth,
                processingIntensity: session.proposal.professional.processingIntensity,
                feedback: feedback,
                listenedSeconds: session.listenedSeconds,
                recordedAt: now
            )
        )
        archive.revision += 1
        removeExpiredEpisodes(now: now)
        if archive.episodes.count > Self.maximumEntries {
            archive.episodes = Array(
                archive.episodes
                    .sorted { $0.recordedAt > $1.recordedAt }
                    .prefix(Self.maximumEntries)
            )
        }
        persist()
    }

    func clear() {
        archive.episodes.removeAll()
        archive.revision += 1
        persist()
    }

    func context(
        for features: AIEqualizerAudioFeatures,
        outputIdentity: String,
        now: Date = Date()
    ) -> AIEqualizerLearningContext? {
        removeExpiredEpisodes(now: now)
        guard !archive.episodes.isEmpty else {
            return emptyContext(for: features.graphicEQMode)
        }

        let normalizedArtist = Self.normalizedToken(features.artist)
        let currentSongIdentifier = "\(features.source):\(features.songID)"
        let currentGenres = Set(features.genreHints.map(Self.normalizedToken).filter { !$0.isEmpty })
        let currentInstruments = Set(features.instrumentHints.map(Self.normalizedToken).filter { !$0.isEmpty })
        var bandSums = Array(repeating: Float(0), count: features.graphicEQMode.bandCount)
        var bassSum: Float = 0
        var trebleSum: Float = 0
        var surroundSum: Float = 0
        var reverbSum: Float = 0
        var widthSum: Float = 0
        var processingSum: Float = 0
        var normalizer: Float = 0
        var relevantEvidence = 0

        for episode in archive.episodes {
            let age = max(0, now.timeIntervalSince(episode.recordedAt))
            let recency = Float(exp(-age / (120 * 24 * 60 * 60)))
            let outputMatch: Float
            if episode.outputIdentity == outputIdentity {
                outputMatch = 1
            } else if episode.outputKind == features.outputKind {
                outputMatch = 0.62
            } else {
                outputMatch = 0.18
            }

            let episodeArtist = Self.normalizedToken(episode.artist)
            let artistMatch: Float = !normalizedArtist.isEmpty && episodeArtist == normalizedArtist
                ? 1.65
                : 1
            let episodeGenres = Set(episode.genreHints.map(Self.normalizedToken).filter { !$0.isEmpty })
            let genreOverlap = currentGenres.intersection(episodeGenres).count
            let genreMatch = 1 + min(0.5, Float(genreOverlap) * 0.22)
            let episodeInstruments = Set(episode.instrumentHints.map(Self.normalizedToken).filter { !$0.isEmpty })
            let instrumentOverlap = currentInstruments.intersection(episodeInstruments).count
            let instrumentMatch = 1 + min(0.35, Float(instrumentOverlap) * 0.12)
            let songMatch: Float = episode.songIdentifier == currentSongIdentifier ? 1.8 : 1
            let feedbackWeight = Self.feedbackWeight(episode.feedback)
            let weight = feedbackWeight * recency * outputMatch * artistMatch
                * genreMatch * instrumentMatch * songMatch
            guard abs(weight) >= 0.025 else { continue }

            let gains = features.graphicEQMode.resampledGains(
                episode.gains,
                from: episode.graphicEQMode
            )
            let average = gains.reduce(0, +) / Float(max(gains.count, 1))
            for index in bandSums.indices {
                bandSums[index] += (gains[index] - average) * weight
            }
            bassSum += episode.bassGain * weight
            trebleSum += episode.trebleGain * weight
            surroundSum += episode.surroundLevel * weight
            reverbSum += episode.reverbLevel * weight
            widthSum += (episode.stereoWidth - 1) * weight
            processingSum += (episode.processingIntensity - 1) * weight
            normalizer += abs(weight)
            relevantEvidence += 1
        }

        guard normalizer >= 0.12, relevantEvidence > 0 else {
            return emptyContext(for: features.graphicEQMode)
        }
        let confidence = min(Float(0.42), (1 - expf(-normalizer / 2.8)) * 0.42)
        let adaptation = min(0.28, 0.10 + confidence * 0.36)
        func adjustment(_ sum: Float, limit: Float) -> Float {
            min(limit, max(-limit, (sum / normalizer) * adaptation))
        }

        return AIEqualizerLearningContext(
            revision: archive.revision,
            evidenceCount: relevantEvidence,
            confidence: confidence,
            bandAdjustments: bandSums.map { adjustment($0, limit: 1.25) },
            bassAdjustment: adjustment(bassSum, limit: 1),
            trebleAdjustment: adjustment(trebleSum, limit: 1),
            surroundAdjustment: adjustment(surroundSum, limit: 0.08),
            reverbAdjustment: adjustment(reverbSum, limit: 0.045),
            stereoWidthAdjustment: adjustment(widthSum, limit: 0.06),
            processingIntensityAdjustment: adjustment(processingSum, limit: 0.14)
        )
    }

    private func emptyContext(for mode: GraphicEQMode) -> AIEqualizerLearningContext {
        AIEqualizerLearningContext(
            revision: archive.revision,
            evidenceCount: 0,
            confidence: 0,
            bandAdjustments: Array(repeating: 0, count: mode.bandCount),
            bassAdjustment: 0,
            trebleAdjustment: 0,
            surroundAdjustment: 0,
            reverbAdjustment: 0,
            stereoWidthAdjustment: 0,
            processingIntensityAdjustment: 0
        )
    }

    private func removeExpiredEpisodes(now: Date = Date()) {
        let count = archive.episodes.count
        archive.episodes.removeAll {
            $0.schemaVersion != Self.schemaVersion
                || now.timeIntervalSince($0.recordedAt) > Self.maximumAge
        }
        if archive.episodes.count != count {
            archive.revision += 1
            persist()
        }
    }

    private func persist() {
        guard let storageURL else {
            AppLogger.error(
                "[AIEqualizerAgent] Learning persistence skipped because storage URL is unavailable",
                step: "ai-tuning.learning-save-failed"
            )
            return
        }
        do {
            let data = try JSONEncoder().encode(archive)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            AppLogger.error(
                "[AIEqualizerAgent] Learning persistence failed evidence=\(archive.episodes.count) error=\(error.localizedDescription)",
                step: "ai-tuning.learning-save-failed"
            )
        }
    }

    private static func feedbackWeight(_ feedback: AIEqualizerLearningFeedback) -> Float {
        switch feedback {
        case .positive: return 1
        case .retained: return 0.28
        case .negative: return -0.72
        case .reset: return -0.48
        case .regenerated: return -0.24
        }
    }

    private static func normalizedToken(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func makeStorageURL() -> URL? {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let directory = applicationSupport.appendingPathComponent(
            "Mono",
            isDirectory: true
        )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory.appendingPathComponent(fileName, isDirectory: false)
        } catch {
            AppLogger.error(
                "[AIEqualizerAgent] Learning storage directory unavailable error=\(error.localizedDescription)",
                step: "ai-tuning.learning-storage-failed"
            )
            return nil
        }
    }
}
