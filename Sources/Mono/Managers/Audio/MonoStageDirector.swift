//  AI 舞台编排 Mono Stage Script —— 把整首歌交给模型做一次
//  "分幕"：按歌词时间轴划出 3~9 个段落，每段独立给出光色、焦点、
//  运动、辉光与歌词强调。它不修改 GPU 着色的输入。
//  每首歌只生成一次（本地缓存），复用 Mono Audio Agent 的模型通道。

import Foundation

// MARK: - 模型

struct MonoStageScript: Codable {
    struct Section: Codable {
        let start: Double
        let end: Double
        let role: String
        let mood: String
        let energy: Double     // 0~1 段落能量基调
        let ambience: Double   // 0~1 空间氛围/梦幻感
        let colorShift: Double // -1~1 冷暖色温走向
        let focus: Double      // -1~1 主光焦点左右位置
        let motion: Double     // 0~1 舞台运动幅度
        let bloom: Double      // 0~1 空间辉光强度
        let lyricLift: Double  // 0~1 歌词强调程度
    }

    let sections: [Section]
    var createdAt = Date()
}

/// 逐帧查询结果（段落边界提前预热，并使用平滑曲线完成落幕过渡）
struct MonoStageCue {
    let role: String
    let mood: String
    let energy: Double
    let ambience: Double
    let colorShift: Double
    let focus: Double
    let motion: Double
    let bloom: Double
    let lyricLift: Double
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
    private static let promptVersion = 3
    private static let boundaryAnticipation = 1.4
    private static let boundarySettle = 2.4

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

    // MARK: - 生命周期

    /// 进入舞台 / 切歌 / 歌词就绪时调用；命中缓存立即可用，
    /// 否则在后台生成一次。歌词太少（纯音乐）不生成。
    func prepare(
        songIdentifier: String,
        songName: String,
        artistName: String,
        duration playbackDuration: Double,
        lines: [AriaLine]
    ) {
        let managedVersion = SongContentConfigurationStore
            .cachedAgentConfiguration(.stageDirector)?.promptVersion
        let key = "\(managedVersion ?? String(Self.promptVersion))|\(songIdentifier)"
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

    // MARK: - 逐帧查询

    /// 当前播放时间对应的段落基调；段落边界前后 2.2s 线性过渡。
    func cue(at time: Double) -> MonoStageCue? {
        guard let script, !script.sections.isEmpty else { return nil }
        let sections = script.sections
        guard let index = sections.lastIndex(where: { $0.start <= time }) else {
            return Self.cue(from: sections[0])
        }

        let current = sections[index]
        if index > 0, time < current.start + Self.boundarySettle {
            let previous = sections[index - 1]
            let progress = (time - (current.start - Self.boundaryAnticipation))
                / (Self.boundaryAnticipation + Self.boundarySettle)
            return Self.blend(previous, current, progress: progress)
        }

        if index + 1 < sections.count {
            let next = sections[index + 1]
            if time > next.start - Self.boundaryAnticipation {
                let progress = (time - (next.start - Self.boundaryAnticipation))
                    / (Self.boundaryAnticipation + Self.boundarySettle)
                return Self.blend(current, next, progress: progress)
            }
        }

        return Self.cue(from: current)
    }

    private static func cue(from section: MonoStageScript.Section) -> MonoStageCue {
        MonoStageCue(
            role: section.role,
            mood: section.mood,
            energy: section.energy,
            ambience: section.ambience,
            colorShift: section.colorShift,
            focus: section.focus,
            motion: section.motion,
            bloom: section.bloom,
            lyricLift: section.lyricLift
        )
    }

    private static func blend(
        _ source: MonoStageScript.Section,
        _ target: MonoStageScript.Section,
        progress: Double
    ) -> MonoStageCue {
        let clamped = min(1, max(0, progress))
        let amount = clamped * clamped * (3 - 2 * clamped)
        func mix(_ lhs: Double, _ rhs: Double) -> Double {
            lhs + (rhs - lhs) * amount
        }
        return MonoStageCue(
            role: amount < 0.5 ? source.role : target.role,
            mood: amount < 0.5 ? source.mood : target.mood,
            energy: mix(source.energy, target.energy),
            ambience: mix(source.ambience, target.ambience),
            colorShift: mix(source.colorShift, target.colorShift),
            focus: mix(source.focus, target.focus),
            motion: mix(source.motion, target.motion),
            bloom: mix(source.bloom, target.bloom),
            lyricLift: mix(source.lyricLift, target.lyricLift)
        )
    }

    // MARK: - 生成

    private func generate(
        songName: String,
        artistName: String,
        duration: Double,
        lines: [AriaLine]
    ) async throws -> MonoStageScript {
        let managedAgent = await SongContentConfigurationStore.shared.agentConfiguration(.stageDirector)
        if let managedAgent, !managedAgent.enabled { throw AIEqualizerError.modelUnavailable }
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
            let bundledUserPrompt = Self.userPrompt(
                songName: songName,
                artistName: artistName,
                duration: duration,
                lines: lines
            )
            response = try await client.generate(
                systemPrompt: managedAgent?.systemPrompt(fallback: Self.systemPrompt) ?? Self.systemPrompt,
                userPrompt: managedAgent?.userPrompt(fallback: bundledUserPrompt) ?? bundledUserPrompt,
                configuration: configuration,
                apiKey: apiKey,
                minimumTimeout: managedAgent?.minimumTimeoutSeconds ?? 0,
                options: managedAgent?.generationOptions ?? .standard
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

    // MARK: - 提示词

    private static let systemPrompt = """
    You are Mono Stage Director, the visual director of an immersive lyric stage. \
    Given a song's metadata and its timestamped lyric lines, divide the whole song \
    into narrative sections and assign each section a visual tone.

    Respond with STRICT JSON only (no markdown, no commentary):
    {"sections":[{"start":0,"end":32.5,"role":"前奏","mood":"沉静","energy":0.35,"ambience":0.6,"colorShift":-0.4,"focus":-0.2,"motion":0.28,"bloom":0.52,"lyricLift":0.24}]}

    Rules:
    - 3 to 9 sections; contiguous, non-overlapping, ascending; first start = 0, last end = song duration.
    - energy (0..1): visual intensity of the section. Verses usually 0.25-0.55, \
    pre-chorus rising 0.5-0.7, chorus/drop 0.75-1.0, bridge/outro distinct from adjacent sections.
    - ambience (0..1): dreaminess / spatial haze. High for intros, bridges, ballad passages; low for tight rhythmic passages.
    - role: one short Chinese section role, e.g. 前奏 / 主歌 / 预副歌 / 副歌 / 间奏 / 桥段 / 尾奏.
    - mood: one short Chinese word (2-4 characters), e.g. 沉静 / 蓄势 / 炽热 / 释放 / 梦境 / 回望 / 告别.
    - colorShift (-1..1): cold to warm color direction. Build a deliberate color arc across the full song.
    - focus (-1..1): key-light position from left to right. Do not move it every section without narrative reason.
    - motion (0..1): stage motion. Keep verses restrained; let transitions and choruses open up.
    - bloom (0..1): spatial light bloom. It may be high in dreamy quiet sections without forcing energy high.
    - lyricLift (0..1): lyric emphasis. Raise it for emotionally or narratively important lines, not only loud sections.
    - Preserve contrast: adjacent sections should not receive nearly identical values across every channel.
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

    // MARK: - 解码

    /// 模型响应只含 sections（无 createdAt 等本地字段），用独立 DTO 解码
    private struct ModelSectionOutput: Codable {
        let start: Double
        let end: Double
        let role: String?
        let mood: String
        let energy: Double
        let ambience: Double
        let colorShift: Double?
        let focus: Double?
        let motion: Double?
        let bloom: Double?
        let lyricLift: Double?
    }

    private struct ModelScriptOutput: Codable {
        let sections: [ModelSectionOutput]
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
                let energy = min(1, max(0, section.energy))
                let ambience = min(1, max(0, section.ambience))
                return MonoStageScript.Section(
                    start: max(0, section.start),
                    end: min(max(section.end, section.start + 1), duration + 30),
                    role: String((section.role ?? "段落").prefix(5)),
                    mood: String(section.mood.prefix(6)),
                    energy: energy,
                    ambience: ambience,
                    colorShift: min(1, max(-1, section.colorShift ?? (energy * 1.4 - 0.7))),
                    focus: min(1, max(-1, section.focus ?? 0)),
                    motion: min(1, max(0, section.motion ?? energy)),
                    bloom: min(1, max(0, section.bloom ?? max(ambience, energy * 0.7))),
                    lyricLift: min(1, max(0, section.lyricLift ?? energy))
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
                role: candidate.role,
                mood: candidate.mood,
                energy: candidate.energy,
                ambience: candidate.ambience,
                colorShift: candidate.colorShift,
                focus: candidate.focus,
                motion: candidate.motion,
                bloom: candidate.bloom,
                lyricLift: candidate.lyricLift
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
