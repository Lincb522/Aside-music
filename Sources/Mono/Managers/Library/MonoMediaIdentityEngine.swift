import Foundation

/// SongMirror + Music Assistant 风格的跨平台歌曲身份引擎。
///
/// 外部歌单只提供元数据；本引擎负责把它稳定映射到 Mono 已接入平台的
/// `Song`。成功的强匹配会持久化，后续导入优先使用已确认的平台映射。
@MainActor
final class MonoMediaIdentityEngine {
    static let shared = MonoMediaIdentityEngine()

    struct CandidateResult {
        let song: Song
        let score: Double
        let reason: String
    }

    private struct PersistedMapping: Codable {
        let targetIdentity: String
        let song: Song?
        let score: Double
        let updatedAt: Date
    }

    private struct Store: Codable {
        var version = 1
        var mappings: [String: PersistedMapping] = [:]
    }

    private let fileURL: URL
    private var store: Store

    private init() {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = baseURL.appendingPathComponent("MonoMediaIdentity", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("provider-mappings.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Store.self, from: data)
        {
            store = decoded
        } else {
            store = Store()
        }
    }

    func cachedMatch(for track: ExternalPlaylistTrack) -> CandidateResult? {
        guard let sourceKey = sourceIdentity(for: track),
              let cached = store.mappings[sourceKey],
              let song = cached.song else { return nil }
        AppLogger.info(
            "[SongMirror] 使用已保存映射: \(track.title) → \(song.name) [\(song.musicSource.displayName)]"
        )
        return CandidateResult(song: song, score: 1, reason: "已保存的平台映射")
    }

    func bestMatch(
        for track: ExternalPlaylistTrack,
        among candidates: [Song]
    ) -> CandidateResult? {
        guard !candidates.isEmpty else { return nil }

        if let sourceKey = sourceIdentity(for: track),
           let cached = store.mappings[sourceKey],
           let song = candidates.first(where: {
               PlayerManager.playbackIdentityKey(for: $0) == cached.targetIdentity
           })
        {
            AppLogger.info(
                "[SongMirror] 恢复旧映射: \(track.title) → \(song.name) [\(song.musicSource.displayName)]"
            )
            return CandidateResult(song: song, score: 1, reason: "已保存的平台映射")
        }

        if let requestedISRC = normalizedISRC(track.isrc),
           let song = candidates.first(where: {
               normalizedISRC($0.appleMusicISRC) == requestedISRC
           })
        {
            learn(track: track, song: song, score: 1)
            AppLogger.info(
                "[SongMirror] ISRC 精确匹配: \(track.title) → \(song.name) [\(song.musicSource.displayName)]"
            )
            return CandidateResult(song: song, score: 1, reason: "ISRC 精确匹配")
        }

        let ranked = candidates.compactMap { song -> CandidateResult? in
            guard let score = score(track: track, candidate: song) else { return nil }
            return CandidateResult(song: song, score: score, reason: "标题、歌手、版本与时长匹配")
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return sourcePriority(lhs.song.musicSource) < sourcePriority(rhs.song.musicSource)
            }
            return lhs.score > rhs.score
        }

        guard let best = ranked.first, best.score >= 0.79 else { return nil }

        // 分数相近时不自动固化，避免把同名翻唱或现场版写成永久映射。
        if ranked.count > 1, best.score - ranked[1].score < 0.025, best.score < 0.94 {
            return nil
        }

        if best.score >= 0.88 {
            learn(track: track, song: best.song, score: best.score)
        }
        AppLogger.info(
            "[SongMirror] 元数据匹配: \(track.title) → \(best.song.name) [\(best.song.musicSource.displayName)] score=\(String(format: "%.3f", best.score))"
        )
        return best
    }

    private func learn(track: ExternalPlaylistTrack, song: Song, score: Double) {
        guard let sourceKey = sourceIdentity(for: track) else { return }
        store.mappings[sourceKey] = PersistedMapping(
            targetIdentity: PlayerManager.playbackIdentityKey(for: song),
            song: song,
            score: score,
            updatedAt: Date()
        )

        // 防止长期导入后映射文件无限增长；仅保留最近使用的映射。
        if store.mappings.count > 20_000 {
            let retained = store.mappings
                .sorted { $0.value.updatedAt > $1.value.updatedAt }
                .prefix(16_000)
            store.mappings = Dictionary(
                uniqueKeysWithValues: retained.map { ($0.key, $0.value) }
            )
        }
        persist()
    }

    private func sourceIdentity(for track: ExternalPlaylistTrack) -> String? {
        if let externalID = track.externalID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !externalID.isEmpty
        {
            return "\(track.provider.rawValue):\(externalID)"
        }

        let title = normalized(track.title)
        guard !title.isEmpty else { return nil }
        let artist = normalized(track.artist)
        let durationBucket = (track.durationMilliseconds ?? 0) / 2_000
        return "\(track.provider.rawValue):meta:\(title)|\(artist)|\(durationBucket)"
    }

    private func score(track: ExternalPlaylistTrack, candidate: Song) -> Double? {
        let requestedTitle = titleCore(track.title)
        let candidateTitle = titleCore(candidate.name)
        let titleScore = textSimilarity(requestedTitle, candidateTitle)
        guard titleScore >= 0.72 else { return nil }

        let requestedVersions = versionMarkers(in: track.title)
        let candidateVersions = versionMarkers(in: candidate.name)
        if requestedVersions != candidateVersions,
           !requestedVersions.isEmpty || !candidateVersions.isEmpty
        {
            return nil
        }

        let artistScore: Double
        if track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            artistScore = 0.72
        } else {
            artistScore = textSimilarity(track.artist, candidate.artistName)
            guard artistScore >= 0.48 else { return nil }
        }

        let durationScore: Double
        if let expected = track.durationMilliseconds,
           expected > 0,
           let actual = candidate.dt,
           actual > 0
        {
            let delta = abs(expected - actual)
            // Music Assistant 的稳健策略：软 ID 相同时仍用时长排除错误版本。
            guard delta <= 8_000 else { return nil }
            durationScore = max(0.2, 1 - Double(delta) / 10_000)
        } else {
            durationScore = 0.68
        }

        let albumScore: Double
        if let requestedAlbum = track.album,
           !requestedAlbum.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let candidateAlbum = candidate.album?.name,
           !candidateAlbum.isEmpty
        {
            albumScore = textSimilarity(requestedAlbum, candidateAlbum)
        } else {
            albumScore = 0.66
        }

        var finalScore =
            titleScore * 0.50 +
            artistScore * 0.27 +
            durationScore * 0.17 +
            albumScore * 0.06

        if let preferred = track.preferredSource, candidate.musicSource == preferred {
            finalScore += 0.015
        }
        return min(finalScore, 1)
    }

    private func sourcePriority(_ source: MusicSource) -> Int {
        switch source {
        case .netease: 0
        case .qqmusic: 1
        case .kugou: 2
        case .qishui: 3
        case .appleMusic: 4
        case .local: 5
        }
    }

    private func normalizedISRC(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.uppercased()
            .replacingOccurrences(of: #"[^A-Z0-9]"#, with: "", options: .regularExpression)
        return result.count >= 10 ? result : nil
    }

    private func titleCore(_ value: String) -> String {
        value
            .replacingOccurrences(
                of: #"\s*[\(\[（【].*?(feat\.?|ft\.?|featuring|伴奏|现场|live|remix|重制).*?[\)\]）】]\s*"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"\s+(feat\.?|ft\.?|featuring)\s+.+$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
    }

    private func normalized(_ value: String, transliterated: Bool = false) -> String {
        var result = value.precomposedStringWithCompatibilityMapping
        if transliterated {
            result = result.applyingTransform(.toLatin, reverse: false) ?? result
        }
        return result
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "zh_Hans")
            )
            .lowercased()
            .replacingOccurrences(of: #"[\p{P}\p{S}\s]+"#, with: "", options: .regularExpression)
    }

    private func textSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsForms = [normalized(lhs), normalized(lhs, transliterated: true)]
        let rhsForms = [normalized(rhs), normalized(rhs, transliterated: true)]
        return lhsForms.flatMap { left in
            rhsForms.map { right in similarity(left, right) }
        }.max() ?? 0
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }
        if lhs.contains(rhs) || rhs.contains(lhs) {
            return 0.86 + 0.14 * Double(min(lhs.count, rhs.count)) / Double(max(lhs.count, rhs.count))
        }

        let lhsBigrams = ngrams(lhs, width: 2)
        let rhsBigrams = ngrams(rhs, width: 2)
        guard !lhsBigrams.isEmpty, !rhsBigrams.isEmpty else { return 0 }
        let intersection = lhsBigrams.intersection(rhsBigrams).count
        return (2 * Double(intersection)) / Double(lhsBigrams.count + rhsBigrams.count)
    }

    private func ngrams(_ value: String, width: Int) -> Set<String> {
        let characters = Array(value)
        guard characters.count >= width else { return [value] }
        return Set((0 ... characters.count - width).map {
            String(characters[$0 ..< $0 + width])
        })
    }

    private func versionMarkers(in value: String) -> Set<String> {
        let lowercased = value.lowercased()
        let markers = [
            "live", "现场", "remix", "混音", "acoustic", "不插电",
            "remaster", "重制", "sped up", "slowed", "instrumental",
            "伴奏", "demo", "翻唱", "cover", "dj",
        ]
        return Set(markers.filter(lowercased.contains))
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
