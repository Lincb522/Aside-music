//
//  MonoStageDirector.swift
//  Monologue
//
//  AI 舞台导演 Mono Stage Script —— 把整首歌交给模型做一次
//  "分幕"：按歌词时间轴划出 3~9 个段落，每段给出基调（沉静/蓄势/
//  炽热/释放/梦境…）、能量与氛围值。沉浸舞台逐帧取当前段落，
//  温和缩放镜头冲击、光场能量与底光，让整场视觉有叙事起伏。
//  每首歌只生成一次（本地缓存），复用 Mono Audio Agent 的模型通道。
//

import Foundation

// MARK: - 模型

struct MonoStageScript: Codable {
    struct Section: Codable {
        let start: Double
        let end: Double
        let mood: String
        let energy: Double     // 0~1 段落能量基调
        let ambience: Double   // 0~1 空间氛围/梦幻感
    }

    let sections: [Section]
    var createdAt = Date()
}

/// 逐帧查询结果（段落边界做 2.2s 线性过渡）
struct MonoStageCue {
    let mood: String
    let energy: Double
    let ambience: Double
}

// MARK: - 导演

@MainActor
final class MonoStageDirector: ObservableObject {
    static let shared = MonoStageDirector()

    enum Phase: Equatable {
        case idle
        case generating
        case ready
        case failed
        /// 歌词太少（纯音乐/短歌词），本曲不参与编排
        case unavailable
    }

    @Published private(set) var phase: Phase = .idle
    /// 当前脚本的分幕数（设置页状态展示用）
    @Published private(set) var sectionCount = 0

    /// 提示词/schema 版本：升级后旧缓存整体作废
    private static let promptVersion = 2
    private static let boundaryBlend = 2.2

    private let client = AIProviderClient()
    private let providerStore = AIProviderConfigurationStore.shared
    private let usageLimiter = AIUsageLimiter.shared
    private let cacheStore = MonoStageScriptCacheStore()

    private var script: MonoStageScript?
    private var currentKey = ""
    private var generationTask: Task<Void, Never>?
    /// 本次舞台会话里已失败过的 key：不再自动重试，避免反复打请求
    private var failedKeys: Set<String> = []

    private init() {}

    // MARK: 生命周期

    /// 进入舞台 / 切歌 / 歌词就绪时调用；命中缓存立即可用，
    /// 否则在后台生成一次。歌词太少（纯音乐）不生成。
    func prepare(
        songIdentifier: String,
        songName: String,
        artistName: String,
        duration playbackDuration: Double,
        lines: [AriaLine]
    ) {
        let key = "\(Self.promptVersion)|\(songIdentifier)"
        if currentKey != key {
            currentKey = key
            script = cacheStore.value(for: key)
            phase = script == nil ? .idle : .ready
            sectionCount = script?.sections.count ?? 0
            generationTask?.cancel()
            generationTask = nil
        }
        if failedKeys.contains(key) { phase = .failed }
        guard script == nil, generationTask == nil, !failedKeys.contains(key) else { return }

        let lyricLines = lines.filter { !$0.isInterlude && !$0.isCredit }
        let duration = max(playbackDuration, lyricLines.last?.endTime ?? 0)
        guard lyricLines.count >= 6, duration > 40 else {
            phase = .unavailable
            return
        }

        phase = .generating
        generationTask = Task { [weak self] in
            guard let self else { return }
            defer { self.generationTask = nil }
            do {
                let script = try await self.generate(
                    songName: songName,
                    artistName: artistName,
                    duration: duration,
                    lines: lyricLines
                )
                guard !Task.isCancelled, self.currentKey == key else { return }
                self.script = script
                self.cacheStore.set(script, for: key)
                self.phase = .ready
                self.sectionCount = script.sections.count
                AppLogger.info(
                    "[MonoStageDirector] Stage script ready song=\(songIdentifier) sections=\(script.sections.count)",
                    step: "stage-director.ready"
                )
            } catch is CancellationError {
                if self.currentKey == key { self.phase = .idle }
            } catch {
                guard self.currentKey == key else { return }
                self.failedKeys.insert(key)
                self.phase = .failed
                AppLogger.warning(
                    "[MonoStageDirector] Stage script failed song=\(songIdentifier): \(error.localizedDescription)",
                    step: "stage-director.failed"
                )
            }
        }
    }

    /// 关闭功能 / 离开舞台时停止在途生成。
    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        if phase == .generating { phase = .idle }
    }

    /// 手动重开开关时解除失败锁，允许对当前歌曲再试一次。
    func resetFailureLock() {
        failedKeys.removeAll()
        if phase == .failed { phase = .idle }
    }

    // MARK: 逐帧查询

    /// 当前播放时间对应的段落基调；段落边界前后 2.2s 线性过渡。
    func cue(at time: Double) -> MonoStageCue? {
        guard let script, !script.sections.isEmpty else { return nil }
        let sections = script.sections
        guard let index = sections.lastIndex(where: { $0.start <= time }) else {
            return MonoStageCue(
                mood: sections[0].mood,
                energy: sections[0].energy,
                ambience: sections[0].ambience
            )
        }

        let current = sections[index]
        var energy = current.energy
        var ambience = current.ambience

        // 靠近下一段边界时向下一段过渡
        if index + 1 < sections.count {
            let next = sections[index + 1]
            let untilNext = next.start - time
            if untilNext < Self.boundaryBlend, untilNext >= 0 {
                let mix = 1 - untilNext / Self.boundaryBlend
                energy += (next.energy - energy) * mix * 0.5
                ambience += (next.ambience - ambience) * mix * 0.5
            }
        }
        // 刚跨过本段起点时从上一段过渡进来
        if index > 0 {
            let previous = sections[index - 1]
            let sinceStart = time - current.start
            if sinceStart < Self.boundaryBlend, sinceStart >= 0 {
                let mix = 1 - sinceStart / Self.boundaryBlend
                energy += (previous.energy - energy) * mix * 0.5
                ambience += (previous.ambience - ambience) * mix * 0.5
            }
        }

        return MonoStageCue(
            mood: current.mood,
            energy: min(1, max(0, energy)),
            ambience: min(1, max(0, ambience))
        )
    }

    // MARK: 生成

    private func generate(
        songName: String,
        artistName: String,
        duration: Double,
        lines: [AriaLine]
    ) async throws -> MonoStageScript {
        providerStore.refreshRemoteConfigurationInBackgroundIfNeeded()
        let configuration = providerStore.requestConfiguration
        let apiKey = providerStore.requestAPIKey
        if configuration.wireProtocol.requiresAPIKey,
           apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AIEqualizerError.missingAPIKey
        }

        try Task.checkCancellation()
        let reservation = try usageLimiter.reserveRequest(limits: providerStore.usageLimits)
        let response: String
        do {
            response = try await client.generate(
                systemPrompt: Self.systemPrompt,
                userPrompt: Self.userPrompt(
                    songName: songName,
                    artistName: artistName,
                    duration: duration,
                    lines: lines
                ),
                configuration: configuration,
                apiKey: apiKey
            )
        } catch {
            if AIUsageLimiter.shouldRefundReservation(for: error) {
                usageLimiter.releaseReservation(reservation)
            }
            throw error
        }
        try Task.checkCancellation()
        return try Self.decodeScript(from: response, duration: duration)
    }

    // MARK: 提示词

    private static let systemPrompt = """
    You are Mono Stage Director, the visual director of an immersive lyric stage. \
    Given a song's metadata and its timestamped lyric lines, divide the whole song \
    into narrative sections and assign each section a visual tone.

    Respond with STRICT JSON only (no markdown, no commentary):
    {"sections":[{"start":0,"end":32.5,"mood":"沉静","energy":0.35,"ambience":0.6}]}

    Rules:
    - 3 to 9 sections; contiguous, non-overlapping, ascending; first start = 0, last end = song duration.
    - energy (0..1): visual intensity of the section. Verses usually 0.25-0.55, \
    pre-chorus rising 0.5-0.7, chorus/drop 0.75-1.0, bridge/outro distinct from adjacent sections.
    - ambience (0..1): dreaminess / spatial haze. High for intros, bridges, ballad passages; low for tight rhythmic passages.
    - mood: one short Chinese word (2-4 characters), e.g. 沉静 / 蓄势 / 炽热 / 释放 / 梦境 / 回望 / 告别.
    - Lines marked (副歌) are chorus lines; use them to locate the high-energy sections.
    - Base boundaries on the given timestamps; do not invent times beyond the duration.
    """

    private static func userPrompt(
        songName: String,
        artistName: String,
        duration: Double,
        lines: [AriaLine]
    ) -> String {
        var body = "Song: \(songName)\nArtist: \(artistName)\nDuration: \(String(format: "%.1f", duration))s\n\nLyrics:\n"
        // 均匀抽样限制行数：超长歌词只保留 90 行以内，保证时间轴覆盖全曲
        let step = max(1, Int(ceil(Double(lines.count) / 90.0)))
        for (index, line) in lines.enumerated() where index % step == 0 {
            let tag = line.isChorus ? " (副歌)" : ""
            body += "[\(String(format: "%.1f", line.startTime))-\(String(format: "%.1f", line.endTime))]\(tag) \(line.fullText)\n"
        }
        return body
    }

    // MARK: 解码

    /// 模型响应只含 sections（无 createdAt 等本地字段），用独立 DTO 解码
    private struct ModelScriptOutput: Codable {
        let sections: [MonoStageScript.Section]
    }

    private static func decodeScript(from rawText: String, duration: Double) throws -> MonoStageScript {
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
              let decoded = try? JSONDecoder().decode(ModelScriptOutput.self, from: data) else {
            throw AIEqualizerError.invalidResponse
        }

        // 规整：模型只决定各幕起点与基调；本地重新计算连续边界，避免
        // 缺口、重叠或最后一幕提前结束造成视觉停摆。
        let candidates = decoded.sections
            .filter { $0.end > $0.start && $0.start >= 0 && $0.start < duration + 30 }
            .sorted { $0.start < $1.start }
            .prefix(9)
            .map { section in
                MonoStageScript.Section(
                    start: max(0, section.start),
                    end: min(max(section.end, section.start + 1), duration + 30),
                    mood: String(section.mood.prefix(6)),
                    energy: min(1, max(0, section.energy)),
                    ambience: min(1, max(0, section.ambience))
                )
            }
        guard candidates.count >= 2 else { throw AIEqualizerError.invalidResponse }

        var sections: [MonoStageScript.Section] = []
        for index in candidates.indices {
            let candidate = candidates[index]
            let start = index == candidates.startIndex
                ? 0
                : min(max(candidate.start, sections.last?.end ?? 0), duration)
            let end = index + 1 < candidates.count
                ? min(max(candidates[index + 1].start, start + 1), duration)
                : duration
            guard end > start else { continue }
            sections.append(MonoStageScript.Section(
                start: start,
                end: end,
                mood: candidate.mood,
                energy: candidate.energy,
                ambience: candidate.ambience
            ))
        }
        guard sections.count >= 2 else { throw AIEqualizerError.invalidResponse }
        return MonoStageScript(sections: Array(sections))
    }
}

// MARK: - 本地缓存（UserDefaults，按创建时间保留 30 首）

private final class MonoStageScriptCacheStore {
    private static let storageKey = "mono.stage.director.cache.v1"
    private var values: [String: MonoStageScript]

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: MonoStageScript].self, from: data)
        else {
            values = [:]
            return
        }
        values = decoded
    }

    func value(for key: String) -> MonoStageScript? {
        values[key]
    }

    func set(_ value: MonoStageScript, for key: String) {
        values[key] = value
        if values.count > 30 {
            let retained = values.sorted { $0.value.createdAt > $1.value.createdAt }.prefix(30)
            values = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
        }
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
