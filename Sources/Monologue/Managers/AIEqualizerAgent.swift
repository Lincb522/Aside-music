import Foundation
@preconcurrency import Combine

private enum AIEqualizerAnalysisTrigger {
    case manual
    case automatic
}

@MainActor
final class AIEqualizerAgent: ObservableObject {
    static let shared = AIEqualizerAgent()

    @Published private(set) var phase: AIEqualizerAgentPhase = .idle
    @Published private(set) var proposal: AIEqualizerProposal?
    @Published private(set) var measuredFeatures: AIEqualizerAudioFeatures?
    @Published private(set) var appliedProposalID: UUID?
    @Published private(set) var samplingStage: AIEqualizerSamplingStage = .preparing
    @Published private(set) var generationStage: AIEqualizerGenerationStage = .preparing
    @Published var samplingMode: AIEqualizerSamplingMode {
        didSet { UserDefaults.standard.set(samplingMode.rawValue, forKey: Self.samplingModeKey) }
    }
    @Published var customSamplingDuration: Double {
        didSet {
            let normalized = min(90, max(8, customSamplingDuration))
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
                scheduledAutomaticRunID = nil
                scheduledAutomaticSongIdentifier = nil
                if phase.isWorking { phase = .idle }
                EQManager.shared.restoreProcessingBeforeAI(reason: "automatic-disabled")
                appliedProposalID = nil
                appliedSongIdentifier = nil
            }
        }
    }

    private static let autoKey = "ai.eq.agent.auto-configure"
    private static let samplingModeKey = "ai.eq.agent.sampling-mode"
    private static let customSamplingDurationKey = "ai.eq.agent.custom-sampling-duration"
    private static let playerStatusKey = "ai.eq.agent.player-status"
    private let sampler = AIEqualizerFeatureSampler()
    private let client = AIProviderClient()
    private let providerStore = AIProviderConfigurationStore.shared
    private let usageLimiter = AIUsageLimiter.shared
    private var cancellables = Set<AnyCancellable>()
    private var analysisTask: Task<Void, Never>?
    private var automaticTask: Task<Void, Never>?
    private var automaticRetryTask: Task<Void, Never>?
    private let proposalCache = AIEqualizerProposalCacheStore()
    private var activeAnalysisRunID: UUID?
    private var activeAnalysisSongIdentifier: String?
    private var scheduledAutomaticRunID: UUID?
    private var scheduledAutomaticSongIdentifier: String?
    private var appliedSongIdentifier: String?
    private var observedSongIdentifier: String?
    private var automaticSamplingRetryCount: [String: Int] = [:]

    private init() {
        let defaults = UserDefaults.standard
        automaticConfigurationEnabled = defaults.bool(forKey: Self.autoKey)
        samplingMode = defaults.string(forKey: Self.samplingModeKey)
            .flatMap(AIEqualizerSamplingMode.init(rawValue:)) ?? .smart
        let savedDuration = defaults.double(forKey: Self.customSamplingDurationKey)
        customSamplingDuration = savedDuration > 0 ? min(90, max(8, savedDuration)) : 30
        showsPlayerTuningStatus = defaults.object(forKey: Self.playerStatusKey) == nil
            ? true
            : defaults.bool(forKey: Self.playerStatusKey)
        if !automaticConfigurationEnabled {
            EQManager.shared.restoreProcessingBeforeAI(reason: "agent-restored-disabled")
        }

        let player = PlayerManager.shared
        observedSongIdentifier = player.currentSong.map { "\($0.musicSource.rawValue):\($0.id)" }
        player.$currentSong
            .map { song in
                song.map { "\($0.musicSource.rawValue):\($0.id)" }
            }
            .removeDuplicates()
            .sink { [weak self] identifier in
                guard let self else { return }
                guard self.observedSongIdentifier != identifier else { return }
                self.observedSongIdentifier = identifier
                self.analysisTask?.cancel()
                self.automaticTask?.cancel()
                self.automaticRetryTask?.cancel()
                self.activeAnalysisRunID = nil
                self.activeAnalysisSongIdentifier = nil
                self.scheduledAutomaticRunID = nil
                self.scheduledAutomaticSongIdentifier = nil
                if let identifier, self.automaticConfigurationEnabled {
                    EQManager.shared.prepareForAIAnalysis(songIdentifier: identifier)
                } else {
                    EQManager.shared.restoreProcessingBeforeAI(
                        reason: identifier == nil ? "queue-cleared" : "automatic-inactive"
                    )
                }
                self.proposal = nil
                self.measuredFeatures = nil
                self.appliedProposalID = nil
                self.appliedSongIdentifier = nil
                self.automaticSamplingRetryCount.removeAll()
                self.samplingStage = .preparing
                self.generationStage = .preparing
                self.phase = .idle
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
                  self.automaticConfigurationEnabled,
                  PlayerManager.shared.currentSong != nil else { return }
            self.analysisTask?.cancel()
            self.automaticTask?.cancel()
            self.automaticRetryTask?.cancel()
            self.activeAnalysisRunID = nil
            self.activeAnalysisSongIdentifier = nil
            self.scheduledAutomaticRunID = nil
            self.scheduledAutomaticSongIdentifier = nil
            EQManager.shared.restoreProcessingBeforeAI(reason: "output-changed")
            self.proposal = nil
            self.measuredFeatures = nil
            self.appliedProposalID = nil
            self.appliedSongIdentifier = nil
            self.automaticSamplingRetryCount.removeAll()
            self.phase = .idle
            self.scheduleAutomaticAnalysis()
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
    }

    func analyzeCurrentSong() {
        automaticTask?.cancel()
        automaticRetryTask?.cancel()
        analysisTask?.cancel()
        automaticSamplingRetryCount.removeAll()
        scheduledAutomaticRunID = nil
        scheduledAutomaticSongIdentifier = nil
        activeAnalysisRunID = nil
        activeAnalysisSongIdentifier = nil
        analysisTask = Task { [weak self] in
            await self?.runAnalysis()
        }
    }

    func cancelAnalysis() {
        automaticTask?.cancel()
        automaticRetryTask?.cancel()
        analysisTask?.cancel()
        analysisTask = nil
        automaticSamplingRetryCount.removeAll()
        scheduledAutomaticRunID = nil
        scheduledAutomaticSongIdentifier = nil
        activeAnalysisRunID = nil
        activeAnalysisSongIdentifier = nil
        if phase.isWorking { phase = .idle }
    }

    func applyCurrentProposal() {
        guard let proposal else { return }
        apply(proposal)
    }

    func resetToFlat() {
        EQManager.shared.restoreProcessingBeforeAI(reason: "manual-reset")
        EQManager.shared.applyFlat()
        appliedProposalID = nil
        appliedSongIdentifier = nil
    }

    func testProviderConnection() async throws {
        let configuration = try await resolvedProviderConfiguration()
        let text = try await client.generate(
            systemPrompt: AIEqualizerPrompt.system,
            userPrompt: AIEqualizerPrompt.connectivityTest,
            configuration: configuration,
            apiKey: providerStore.apiKey
        )
        _ = try decodeModelOutput(from: text)
    }

    private func scheduleAutomaticAnalysis() {
        guard automaticConfigurationEnabled,
              let scheduledSong = PlayerManager.shared.currentSong else { return }
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

    private func runAnalysis(trigger: AIEqualizerAnalysisTrigger = .manual) async {
        guard let song = PlayerManager.shared.currentSong else {
            phase = .failed(AIEqualizerError.noSong.localizedDescription)
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
            }
        }

        var configuration = providerStore.configuration
        if configuration.wireProtocol.requiresAPIKey,
           providerStore.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .failed(AIEqualizerError.missingAPIKey.localizedDescription)
            return
        }
        do {
            configuration = try await resolvedProviderConfiguration()
        } catch {
            if isCurrentSong(song) {
                phase = .failed(error.localizedDescription)
            }
            return
        }
        guard isCurrentSong(song) else { return }
        let samplingDuration = resolvedSamplingDuration(for: song)
        let samplingDurationText = String(format: "%.1f", samplingDuration)
        AppLogger.info(
            "[AIEqualizerAgent] Analysis prepared songID=\(song.id) mode=\(samplingMode.rawValue) target=\(samplingDurationText)s output=\(EQManager.shared.currentOutputName) protocol=\(configuration.wireProtocol.rawValue) model=\(configuration.resolvedModel)",
            step: "ai-tuning.prepare"
        )
        let outputIdentity = EQManager.shared.currentOutputName.isEmpty
            ? EQManager.shared.currentOutputKind.rawValue
            : "\(EQManager.shared.currentOutputKind.rawValue):\(EQManager.shared.currentOutputName)"
        let cacheKey = "\(AIEqualizerPrompt.version)|mono-agent-v2|\(song.musicSource.rawValue)|\(song.id)|\(configuration.wireProtocol.rawValue)|\(configuration.resolvedModel)|\(outputIdentity)|\(samplingMode.rawValue)|\(Int(samplingDuration.rounded()))"
        if let cached = proposalCache.value(for: cacheKey) {
            automaticSamplingRetryCount[identifier] = nil
            AppLogger.info(
                "[AIEqualizerAgent] Applied cached proposal song=\(identifier) output=\(outputIdentity)",
                step: "ai-tuning.cache-hit"
            )
            proposal = cached
            phase = .ready
            apply(cached)
            return
        }

        do {
            samplingStage = .preparing
            phase = .sampling(progress: 0)
            let features = try await sampler.sample(song: song, duration: samplingDuration) { [weak self] value, stage in
                self?.samplingStage = stage
                self?.phase = .sampling(progress: value)
            }
            try Task.checkCancellation()
            guard isCurrentSong(song) else {
                throw AIEqualizerError.noSong
            }

            measuredFeatures = features
            generationStage = .preparing
            phase = .requesting
            try usageLimiter.reserveRequest(limits: providerStore.usageLimits)
            generationStage = .generating
            let response = try await client.generate(
                systemPrompt: AIEqualizerPrompt.system,
                userPrompt: try AIEqualizerPrompt.userPrompt(features: features),
                configuration: configuration,
                apiKey: providerStore.apiKey
            )
            try Task.checkCancellation()
            generationStage = .validating
            let output = try decodeModelOutput(from: response)
            let result = AIEqualizerProposal(
                songID: song.id,
                output: output,
                features: features,
                provider: configuration.wireProtocol,
                model: configuration.resolvedModel
            )
            generationStage = .finalizing
            proposalCache.set(result, for: cacheKey)
            automaticSamplingRetryCount[identifier] = nil
            proposal = result
            phase = .ready
            if isCurrentSong(song) {
                apply(result)
            }
        } catch is CancellationError {
            AppLogger.info(
                "[AIEqualizerAgent] Analysis cancelled songID=\(song.id) phase=\(String(describing: phase))",
                step: "ai-tuning.cancelled"
            )
            if isCurrentSong(song) { phase = .idle }
        } catch {
            let failurePositionText = String(format: "%.1f", PlayerManager.shared.currentTime)
            let failureDurationText = String(format: "%.1f", PlayerManager.shared.duration)
            AppLogger.error(
                "[AIEqualizerAgent] Analysis failed songID=\(song.id) phase=\(String(describing: phase)) mode=\(samplingMode.rawValue) playerState=\(String(describing: PlayerManager.shared.streamPlayer.state)) appPlaying=\(PlayerManager.shared.isPlaying) loading=\(PlayerManager.shared.isLoading) position=\(failurePositionText)/\(failureDurationText) error=\(error.localizedDescription)",
                step: "ai-tuning.failed"
            )
            if isCurrentSong(song) {
                phase = .failed(error.localizedDescription)
                if trigger == .automatic {
                    scheduleAutomaticSamplingRetryIfNeeded(for: identifier, error: error)
                }
            }
        }
    }

    private func scheduleAutomaticSamplingRetryIfNeeded(
        for identifier: String,
        error: Error
    ) {
        guard automaticConfigurationEnabled,
              let aiError = error as? AIEqualizerError else { return }
        switch aiError {
        case .sampleUnavailable, .playbackRequired:
            break
        default:
            return
        }

        let attempt = (automaticSamplingRetryCount[identifier] ?? 0) + 1
        guard attempt <= 2 else {
            AppLogger.warning(
                "[AIEqualizerAgent] Automatic sampling retries exhausted song=\(identifier)",
                step: "ai-tuning.retry-exhausted"
            )
            return
        }
        automaticSamplingRetryCount[identifier] = attempt
        AppLogger.warning(
            "[AIEqualizerAgent] Automatic sampling retry scheduled song=\(identifier) attempt=\(attempt)",
            step: "ai-tuning.retry-scheduled"
        )
        automaticRetryTask?.cancel()
        automaticRetryTask = Task { [weak self] in
            defer {
                if let self,
                   self.automaticSamplingRetryCount[identifier] == attempt {
                    self.automaticRetryTask = nil
                }
            }
            do {
                try await Task.sleep(for: .seconds(Double(attempt) * 1.5))
            } catch {
                return
            }
            guard let self,
                  self.automaticConfigurationEnabled,
                  PlayerManager.shared.currentSong.map({ self.songIdentifier($0) }) == identifier else {
                return
            }
            self.scheduleAutomaticAnalysis()
        }
    }

    private func apply(_ proposal: AIEqualizerProposal) {
        guard PlayerManager.shared.currentSong?.id == proposal.songID else { return }
        phase = .applying
        let manager = EQManager.shared
        manager.applyAIConfiguration(proposal)
        appliedProposalID = proposal.id
        appliedSongIdentifier = PlayerManager.shared.currentSong.map { songIdentifier($0) }
        phase = .ready
        HapticManager.shared.success()
    }

    private func songIdentifier(_ song: Song) -> String {
        "\(song.musicSource.rawValue):\(song.id)"
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
            requested = 12
        case .deep:
            requested = 45
        case .custom:
            requested = min(90, max(8, customSamplingDuration))
        case .smart:
            switch trackDuration {
            case 0..<75: requested = 14
            case 75..<180: requested = 22
            case 360...: requested = 36
            default: requested = 30
            }
        }

        let remaining = PlayerManager.shared.duration - PlayerManager.shared.currentTime
        guard remaining > 0 else { return requested }
        return min(requested, max(6, remaining - 2))
    }

    private func resolvedProviderConfiguration() async throws -> AIProviderConfiguration {
        let configuration = providerStore.configuration
        let configuredModel = providerStore.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard configuredModel.isEmpty,
              configuration.wireProtocol != .appleIntelligence else {
            return configuration
        }

        let models = try await client.fetchModels(
            configuration: configuration,
            apiKey: providerStore.apiKey
        )
        let preferred = configuration.wireProtocol.defaultModel
        guard let selected = models.contains(preferred) ? preferred : models.first else {
            throw AIEqualizerError.modelUnavailable
        }
        providerStore.model = selected
        return providerStore.configuration
    }

    private func decodeModelOutput(from rawText: String) throws -> AIEqualizerModelOutput {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```JSON", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}"), first <= last {
            text = String(text[first...last])
        }
        guard let data = text.data(using: .utf8),
              let output = try? JSONDecoder().decode(AIEqualizerModelOutput.self, from: data),
              output.gains.count == 10,
              output.gains.allSatisfy({ $0.isFinite }),
              output.preampDB.isFinite,
              output.confidence.isFinite else {
            throw AIEqualizerError.invalidResponse
        }
        return output
    }
}

@MainActor
private final class AIEqualizerProposalCacheStore {
    private static let storageKey = "ai.eq.agent.proposal-cache.v1"
    private static let maximumEntries = 64
    private static let maximumAge: TimeInterval = 45 * 24 * 60 * 60

    private var values: [String: AIEqualizerProposal]

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: AIEqualizerProposal].self, from: data) else {
            values = [:]
            return
        }
        values = decoded
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
        if values.count > Self.maximumEntries {
            let retained = values
                .sorted { $0.value.createdAt > $1.value.createdAt }
                .prefix(Self.maximumEntries)
            values = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
        }
        persist()
    }

    private func removeExpiredEntries(now: Date = Date()) {
        values = values.filter { now.timeIntervalSince($0.value.createdAt) <= Self.maximumAge }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
