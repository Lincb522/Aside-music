import Combine
import Foundation

enum MeditationTopic: String, CaseIterable, Identifiable, Hashable, Codable {
    case all
    case mindfulness
    case focus
    case lightMusic
    case sleep
    case breathing
    case ambient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return String(localized: "meditation_topic_all")
        case .mindfulness: return String(localized: "meditation_topic_mindfulness")
        case .focus: return String(localized: "meditation_topic_focus")
        case .lightMusic: return String(localized: "meditation_topic_light_music")
        case .sleep: return String(localized: "meditation_topic_sleep")
        case .breathing: return String(localized: "meditation_topic_breathing")
        case .ambient: return String(localized: "meditation_topic_ambient")
        }
    }

    var queries: [String] {
        switch self {
        case .all:
            return []
        case .mindfulness:
            return ["冥想", "正念冥想", "静心冥想"]
        case .focus:
            return ["专注力训练", "专注冥想", "注意力训练", "学习专注", "工作专注"]
        case .lightMusic:
            return ["轻音乐", "纯音乐", "治愈轻音乐", "放松音乐", "冥想音乐"]
        case .sleep:
            return ["睡眠冥想", "睡前冥想", "助眠"]
        case .breathing:
            return ["呼吸冥想", "呼吸放松"]
        case .ambient:
            return ["白噪音", "自然声音", "雨声"]
        }
    }
}

@MainActor
final class MeditationModeViewModel: ObservableObject {
    @Published var selectedTopic: MeditationTopic = .all
    @Published private(set) var radios: [RadioStation] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private var radioTopics: [Int: Set<MeditationTopic>] = [:]
    private var isRefreshing = false
    private let searchPageSize = 50
    private let maxSearchPagesPerQuery = 6
    private static let cacheKey = "meditation_mode_radio_results_v1"
    private static let cacheTTL: TimeInterval = AppConfig.Cache.defaultTTL

    var visibleRadios: [RadioStation] {
        guard selectedTopic != .all else { return radios }
        return radios.filter { radioTopics[$0.id]?.contains(selectedTopic) == true }
    }

    var featuredRadios: [RadioStation] {
        Array(radios.prefix(3))
    }

    func loadIfNeeded() async {
        guard radios.isEmpty else {
            isLoading = false
            return
        }

        if restoreCachedResults() {
            isLoading = false
            await refreshContent(showsLoading: false)
        } else {
            await refresh()
        }
    }

    func refresh() async {
        await refreshContent(showsLoading: true)
    }

    private func refreshContent(showsLoading: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if showsLoading {
            isLoading = true
        }
        errorMessage = nil
        defer {
            isRefreshing = false
            if showsLoading {
                isLoading = false
            }
        }

        var collected: [RadioStation] = []
        var topicMap: [Int: Set<MeditationTopic>] = [:]
        var lastError: Error?
        let hadResults = !radios.isEmpty

        for topic in MeditationTopic.allCases where topic != .all {
            for query in topic.queries {
                do {
                    let result = try await searchAllRadios(query: query)
                    for radio in result {
                        collected.append(radio)
                        topicMap[radio.id, default: []].insert(topic)
                    }
                } catch {
                    lastError = error
                    AppLogger.warning("MeditationModeViewModel: 冥想内容搜索失败 \(query) - \(error.localizedDescription)")
                }
            }
        }

        let uniqueRadios = rankRadios(deduplicate(collected))
        if !uniqueRadios.isEmpty {
            radios = uniqueRadios
            radioTopics = topicMap
            cacheResults(radios: uniqueRadios, topicMap: topicMap)
        } else if hadResults {
            if let lastError {
                errorMessage = lastError.localizedDescription
            }
        } else if let lastError {
            errorMessage = lastError.localizedDescription
        }
    }

    @discardableResult
    private func restoreCachedResults() -> Bool {
        guard
            let snapshot = OptimizedCacheManager.shared.getObject(
                forKey: Self.cacheKey,
                type: MeditationModeCacheSnapshot.self
            ),
            !snapshot.radios.isEmpty
        else {
            return false
        }

        radios = snapshot.radios
        radioTopics = snapshot.radioTopics
        errorMessage = nil
        return true
    }

    private func cacheResults(radios: [RadioStation], topicMap: [Int: Set<MeditationTopic>]) {
        let snapshot = MeditationModeCacheSnapshot(radios: radios, radioTopics: topicMap)
        OptimizedCacheManager.shared.setObject(snapshot, forKey: Self.cacheKey, ttl: Self.cacheTTL)
    }

    private func searchAllRadios(query: String) async throws -> [RadioStation] {
        var offset = 0
        var page = 0
        var results: [RadioStation] = []

        while page < maxSearchPagesPerQuery {
            let radios = try await APIService.shared
                .searchDJRadio(keywords: query, limit: searchPageSize, offset: offset)
                .async()

            guard !radios.isEmpty else { break }

            results.append(contentsOf: radios)
            guard radios.count >= searchPageSize else { break }

            offset += radios.count
            page += 1
        }

        return results
    }

    private func deduplicate(_ radios: [RadioStation]) -> [RadioStation] {
        var seen = Set<Int>()
        return radios.filter { radio in
            seen.insert(radio.id).inserted
        }
    }

    private func rankRadios(_ radios: [RadioStation]) -> [RadioStation] {
        radios.sorted { lhs, rhs in
            score(lhs) > score(rhs)
        }
    }

    private func score(_ radio: RadioStation) -> Int {
        let text = [radio.name, radio.desc ?? "", radio.category ?? ""]
            .joined(separator: " ")
            .lowercased()
        let keywords = ["冥想", "正念", "静心", "专注", "注意力", "集中", "学习", "工作", "轻音乐", "纯音乐", "治愈", "音乐", "呼吸", "睡眠", "助眠", "放松", "白噪音", "自然", "雨声"]
        let keywordScore = keywords.reduce(0) { total, keyword in
            total + (text.contains(keyword) ? 80 : 0)
        }
        return keywordScore + min(radio.subCount ?? 0, 100_000) / 1_000 + min(radio.programCount ?? 0, 1_000) / 10
    }
}

private struct MeditationModeCacheSnapshot: Codable {
    let radios: [RadioStation]
    let radioTopics: [Int: Set<MeditationTopic>]
}
