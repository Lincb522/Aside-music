import Foundation
@preconcurrency import Combine

@MainActor
final class AIListeningInsightAgent: ObservableObject {
    static let shared = AIListeningInsightAgent()

    @Published private(set) var phase: AIListeningInsightPhase = .idle
    @Published private(set) var result: AIListeningInsightResult?

    private let client = AIProviderClient()
    private let providerStore = AIProviderConfigurationStore.shared
    private let usageLimiter = AIUsageLimiter.shared
    private var analysisTask: Task<Void, Never>?
    private var currentInputKey = ""
    private var cache: [String: AIListeningInsightResult] = [:]
    private let cacheStore = AIListeningInsightCacheStore()

    deinit { analysisTask?.cancel() }

    func prepare(for input: AIListeningInsightInput) {
        let key = versionedCacheKey(for: input)
        guard currentInputKey != key else { return }
        analysisTask?.cancel()
        currentInputKey = key
        result = cache[key] ?? cacheStore.value(for: key)
        if let result { cache[key] = result }
        phase = result == nil ? .idle : .ready
    }

    func analyze(_ input: AIListeningInsightInput, force: Bool = false) {
        prepare(for: input)
        if !force, result != nil { return }

        analysisTask?.cancel()
        let expectedKey = versionedCacheKey(for: input)
        analysisTask = Task { [weak self] in
            await self?.run(input, expectedKey: expectedKey)
        }
    }

    func cancel() {
        analysisTask?.cancel()
        analysisTask = nil
        if phase.isWorking { phase = .idle }
    }

    private func run(
        _ input: AIListeningInsightInput,
        expectedKey: String
    ) async {
        guard input.totalPlays > 0 else {
            phase = .failed(String(localized: "ai_listening_no_data"))
            return
        }

        do {
            phase = .requesting
            let insight = try await insight(for: input, force: true)
            guard currentInputKey == expectedKey else { return }

            result = insight
            phase = .ready
            HapticManager.shared.success()
        } catch is CancellationError {
            if currentInputKey == expectedKey { phase = .idle }
        } catch {
            guard currentInputKey == expectedKey else { return }
            AppLogger.error("[AIListeningInsightAgent] \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    func insight(
        for input: AIListeningInsightInput,
        force: Bool = false
    ) async throws -> AIListeningInsightResult {
        guard input.totalPlays > 0 else {
            throw AIEqualizerError.sampleUnavailable
        }
        let key = versionedCacheKey(for: input)
        if !force, let cached = cache[key] ?? cacheStore.value(for: key) {
            cache[key] = cached
            return cached
        }

        let configuration = try await resolvedProviderConfiguration()
        try Task.checkCancellation()
        let reservation = try usageLimiter.reserveRequest(limits: providerStore.usageLimits)
        let response: String
        do {
            response = try await client.generate(
                systemPrompt: AIListeningInsightPrompt.system,
                userPrompt: try AIListeningInsightPrompt.userPrompt(input: input),
                configuration: configuration,
                apiKey: providerStore.requestAPIKey
            )
        } catch {
            if AIUsageLimiter.shouldRefundReservation(for: error) {
                usageLimiter.releaseReservation(reservation)
            }
            throw error
        }
        try Task.checkCancellation()
        let output = try decodeOutput(from: response)
        let insight = makeResult(output: output, input: input)
        cache[key] = insight
        cacheStore.set(insight, for: key)
        return insight
    }

    func automaticInsight(for input: AIListeningInsightInput) async -> AIListeningInsightResult {
        do {
            return try await insight(for: input)
        } catch AIEqualizerError.requestFrequencyLimited(let seconds) {
            do {
                try await Task.sleep(for: .seconds(max(1, seconds)))
                return try await insight(for: input)
            } catch {
                AppLogger.warning("[AIListeningInsightAgent] Automatic analysis fallback: \(error.localizedDescription)")
                return fallbackResult(for: input)
            }
        } catch {
            AppLogger.warning("[AIListeningInsightAgent] Automatic analysis fallback: \(error.localizedDescription)")
            return fallbackResult(for: input)
        }
    }

    private func resolvedProviderConfiguration() async throws -> AIProviderConfiguration {
        providerStore.refreshRemoteConfigurationInBackgroundIfNeeded()
        var configuration = providerStore.requestConfiguration
        let apiKey = providerStore.requestAPIKey
        if configuration.wireProtocol.requiresAPIKey,
           apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AIEqualizerError.missingAPIKey
        }

        let configuredModel = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard configuredModel.isEmpty,
              configuration.wireProtocol != .appleIntelligence else {
            return configuration
        }

        let models = try await client.fetchModels(
            configuration: configuration,
            apiKey: apiKey
        )
        let preferred = configuration.wireProtocol.defaultModel
        guard let selected = models.contains(preferred) ? preferred : models.first else {
            throw AIEqualizerError.modelUnavailable
        }
        if providerStore.isUsingRemoteConfiguration {
            configuration.model = selected
            return configuration
        }
        providerStore.model = selected
        configuration = providerStore.requestConfiguration
        return configuration
    }

    private func decodeOutput(from rawText: String) throws -> AIListeningInsightModelOutput {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```JSON", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let first = text.firstIndex(of: "{"),
           let last = text.lastIndex(of: "}"),
           first <= last {
            text = String(text[first...last])
        }
        guard let data = text.data(using: .utf8),
              let output = try? JSONDecoder().decode(AIListeningInsightModelOutput.self, from: data) else {
            throw AIEqualizerError.invalidResponse
        }
        return output
    }

    private func makeResult(
        output: AIListeningInsightModelOutput,
        input: AIListeningInsightInput
    ) -> AIListeningInsightResult {
        let headline = clean(output.headline, limit: 28)
        let summary = clean(output.summary, limit: 120)
        let observations = Array(
            output.observations
                .map { clean($0, limit: 72) }
                .filter { !$0.isEmpty }
                .prefix(3)
        )

        let allText = [headline, summary] + observations
        if !headline.isEmpty,
           !summary.isEmpty,
           observations.count >= 2,
           allText.allSatisfy(isPrimarilyChinese) {
            return AIListeningInsightResult(
                id: UUID(),
                inputKey: input.cacheKey,
                headline: headline,
                summary: summary,
                observations: observations,
                createdAt: Date()
            )
        }
        return fallbackResult(for: input)
    }

    func fallbackResult(for input: AIListeningInsightInput) -> AIListeningInsightResult {
        let duration = ListeningStatsService.Stats.format(seconds: input.totalSeconds)
        let headline: String
        let summary: String

        if let song = input.topSongs.first {
            headline = "\(song.name)，留在这一期"
            if let lyric = song.lyricExcerpt, !lyric.isEmpty {
                let fragment = String(lyric.prefix(28))
                summary = "从「\(fragment)」这一小段开始，\(song.name)成了\(input.periodTitle)里最清晰的声音；\(song.artist)也为这段时间留下了自己的颜色。"
            } else if song.playCount > 1 {
                summary = "\(input.periodTitle)，\(song.name)一次次回到播放列表，\(song.artist)成了这段时间最熟悉的声音。"
            } else {
                summary = "\(input.periodTitle)的声音落在\(song.name)上，\(song.artist)为这段听歌时光留下了最醒目的一笔。"
            }
        } else if let artist = input.topArtists.first {
            headline = "这一期的声音：\(artist.name)"
            summary = "\(input.periodTitle)，\(artist.name)出现在最靠前的位置，也把这一期的听歌记忆串成了一条清晰的线。"
        } else {
            headline = "\(input.periodTitle)听歌回顾"
            summary = "这一期的声音已经落进记录里：共收听 \(duration)，每一次真正播放都保留在这段听歌时光中。"
        }

        var observations: [String] = []
        if input.previousSeconds >= 60 {
            let change = Int(
                ((Double(input.totalSeconds) - Double(input.previousSeconds))
                    / Double(input.previousSeconds) * 100).rounded()
            )
            observations.append("听歌时长较上一周期\(change >= 0 ? "增加" : "减少") \(abs(change))%。")
        } else {
            observations.append("本期收听覆盖 \(input.activeDays) 天，日均 \(ListeningStatsService.Stats.format(seconds: input.dailyAverageSeconds))。")
        }
        observations.append("完整播放率为 \(input.completionRate)%，共听到 \(input.uniqueSongs) 首不同歌曲。")
        if let peakHour = input.peakHour {
            observations.append(String(format: "收听最集中在 %02d:00 至 %02d:00。", peakHour, (peakHour + 1) % 24))
        } else {
            observations.append("本期共出现 \(input.uniqueArtists) 位不同歌手。")
        }

        return AIListeningInsightResult(
            id: UUID(),
            inputKey: input.cacheKey,
            headline: headline,
            summary: summary,
            observations: observations,
            createdAt: Date()
        )
    }

    private func versionedCacheKey(for input: AIListeningInsightInput) -> String {
        "\(AIListeningInsightPrompt.version)|\(input.cacheKey)"
    }

    private func clean(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(normalized.prefix(limit))
    }

    private func isPrimarilyChinese(_ value: String) -> Bool {
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
}

private final class AIListeningInsightCacheStore {
    private static let storageKey = "ai.listening.insight.cache.v2"
    private var values: [String: AIListeningInsightResult]

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: AIListeningInsightResult].self, from: data)
        else {
            values = [:]
            return
        }
        values = decoded
    }

    func value(for key: String) -> AIListeningInsightResult? {
        values[key]
    }

    func set(_ value: AIListeningInsightResult, for key: String) {
        values[key] = value
        if values.count > 24 {
            let retained = values.sorted { $0.value.createdAt > $1.value.createdAt }.prefix(24)
            values = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
        }
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
