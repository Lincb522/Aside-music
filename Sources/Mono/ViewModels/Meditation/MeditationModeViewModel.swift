import Combine
import Foundation

/// 冥想专区的内容主题分类，`queries` 为各主题对应的电台搜索关键词。
enum MeditationTopic: String, CaseIterable, Identifiable, Hashable, Codable {
    case all
    case mindfulness
    case focus
    case lightMusic
    case sleep
    case breathing
    case relax
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
        case .relax: return String(localized: "meditation_topic_relax")
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
        case .relax:
            return ["解压", "放松减压", "舒缓压力", "助眠解压"]
        case .ambient:
            return ["白噪音", "自然声音", "雨声"]
        }
    }
}

/// 冥想模式首页的数据源：聚合两类内容并按主题筛选——
/// 一是通过关键词搜索的电台（RadioStation），二是网易云"助眠解压"专区资源（SatiResource）。
/// 结果整体写入缓存，启动时先恢复缓存再后台刷新。
@MainActor
final class MeditationModeViewModel: ObservableObject {
    // MARK: - 状态

    @Published var selectedTopic: MeditationTopic = .all
    @Published private(set) var radios: [RadioStation] = []
    @Published private(set) var satiResources: [SatiResource] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    /// 电台 id / Sati 资源 trackId 到所属主题集合的映射，驱动主题筛选。
    private var radioTopics: [Int: Set<MeditationTopic>] = [:]
    private var satiResourceTopics: [Int: Set<MeditationTopic>] = [:]
    private var satiTagsByTag: [String: SatiTag] = [:]
    private var satiScene: SatiScene?
    private var isRefreshing = false
    private let searchPageSize = 50
    private let maxSearchPagesPerQuery = 6
    private static let cacheKey = "meditation_mode_results_v2"
    private static let cacheTTL: TimeInterval = AppConfig.Cache.defaultTTL
    /// 需要拉取的 Sati 分类标签（RCMD 为推荐流，其余为固定栏目）。
    private static let preferredSatiTags = [
        "RCMD",
        "sleep",
        "meditation",
        "relax",
        "lightmusic",
        "naturalMusic",
        "cloudStudyRoom",
        "goodnightStory",
        "starGoodNight",
        "dokodemo"
    ]

    // MARK: - 筛选后的展示数据

    var visibleRadios: [RadioStation] {
        guard selectedTopic != .all else { return radios }
        return radios.filter { radioTopics[$0.id]?.contains(selectedTopic) == true }
    }

    var visibleSatiResources: [SatiResource] {
        guard selectedTopic != .all else { return satiResources }
        return satiResources.filter { resource in
            satiResourceTopics[resource.playableTrackId]?.contains(selectedTopic) == true
        }
    }

    var visibleItems: [MeditationContentItem] {
        let satiItems = visibleSatiResources.map(makeSatiItem)
        let radioItems = visibleRadios.map(makeRadioItem)
        return satiItems + radioItems
    }

    var visibleContentCount: Int {
        visibleItems.count
    }

    var featuredRadios: [RadioStation] {
        Array(radios.prefix(3))
    }

    // MARK: - 加载与刷新

    /// 首次进入时调用：已有数据直接返回；命中缓存则先展示缓存再静默刷新，否则带 loading 全量加载。
    func loadIfNeeded() async {
        guard radios.isEmpty && satiResources.isEmpty else {
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

    /// 全量刷新：先拉 Sati 资源，再逐主题逐关键词搜索电台；
    /// 有新结果才覆盖旧数据并写缓存，全部失败时保留旧数据并展示错误。
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
        let hadResults = !radios.isEmpty || !satiResources.isEmpty

        let satiCollection = await fetchSatiContent()
        let uniqueSatiResources = deduplicateSatiResources(satiCollection.resources)
        if !uniqueSatiResources.isEmpty {
            satiResources = uniqueSatiResources
            satiResourceTopics = satiCollection.topicMap
            satiTagsByTag = satiCollection.tagsByTag
            satiScene = satiCollection.scene
        }

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
        if !uniqueRadios.isEmpty || !uniqueSatiResources.isEmpty {
            if !uniqueRadios.isEmpty {
                radios = uniqueRadios
                radioTopics = topicMap
            }

            if !uniqueSatiResources.isEmpty {
                satiResources = uniqueSatiResources
                satiResourceTopics = satiCollection.topicMap
                satiTagsByTag = satiCollection.tagsByTag
                satiScene = satiCollection.scene
            }

            cacheResults(
                radios: radios,
                radioTopicMap: radioTopics,
                satiResources: satiResources,
                satiTopicMap: satiResourceTopics,
                satiTags: Array(satiTagsByTag.values),
                satiScene: satiScene
            )
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
            !snapshot.radios.isEmpty || !snapshot.satiResources.isEmpty
        else {
            return false
        }

        radios = snapshot.radios
        radioTopics = snapshot.radioTopics
        satiResources = snapshot.satiResources
        satiResourceTopics = snapshot.satiResourceTopics
        satiTagsByTag = Self.makeTagMap(snapshot.satiTags)
        satiScene = snapshot.satiScene
        errorMessage = nil
        return true
    }

    /// 把列表项转换为播放源；Sati 资源附带当前筛选下的同类资源作为播放队列上下文。
    func playbackSource(for item: MeditationContentItem) -> MeditationPlaybackSource {
        switch item.source {
        case .radio(let radio):
            return .radio(radio)
        case .sati(let resource):
            return .sati(resources: satiPlaybackContext(for: resource), startResource: resource)
        }
    }

    private func cacheResults(
        radios: [RadioStation],
        radioTopicMap: [Int: Set<MeditationTopic>],
        satiResources: [SatiResource],
        satiTopicMap: [Int: Set<MeditationTopic>],
        satiTags: [SatiTag],
        satiScene: SatiScene?
    ) {
        let snapshot = MeditationModeCacheSnapshot(
            radios: radios,
            radioTopics: radioTopicMap,
            satiResources: satiResources,
            satiResourceTopics: satiTopicMap,
            satiTags: satiTags,
            satiScene: satiScene
        )
        OptimizedCacheManager.shared.setObject(snapshot, forKey: Self.cacheKey, ttl: Self.cacheTTL)
    }

    // MARK: - Sati 资源拉取

    /// 拉取"助眠解压"内容：按预设标签逐个加载资源，并把时间场景推荐插到最前；
    /// 同时根据资源分类映射到冥想主题供筛选使用。
    private func fetchSatiContent() async -> MeditationSatiCollection {
        var tagsByTag: [String: SatiTag] = [:]
        if let tags = try? await APIService.shared.fetchSatiTags().async() {
            tagsByTag = Self.makeTagMap(tags)
        }

        let tagsToLoad = Self.preferredSatiTags.filter { tag in
            tagsByTag[tag] != nil || !Self.topics(forSatiTag: tag).isEmpty || tag == "RCMD"
        }

        var resources: [SatiResource] = []
        var topicMap: [Int: Set<MeditationTopic>] = [:]

        for tag in tagsToLoad {
            do {
                let loadedResources = try await APIService.shared.fetchSatiResources(tag: tag).async()
                resources.append(contentsOf: loadedResources)

                let fallbackTopics = Self.topics(forSatiTag: tag)
                for resource in loadedResources {
                    let topics = Self.topics(forSatiTag: resource.category).union(fallbackTopics)
                    for topic in topics {
                        topicMap[resource.playableTrackId, default: []].insert(topic)
                    }
                }
            } catch {
                AppLogger.warning("MeditationModeViewModel: 助眠解压资源加载失败 tag=\(tag) - \(error.localizedDescription)")
            }
        }

        var scene: SatiScene?
        do {
            let timeScene = try await APIService.shared.fetchSatiTimesceneResources().async()
            scene = timeScene.sceneVO
            resources.insert(contentsOf: timeScene.resources, at: 0)

            for resource in timeScene.resources {
                let topics = Self.topics(forSatiTag: resource.category)
                let resolvedTopics = topics.isEmpty ? Set([MeditationTopic.sleep]) : topics
                for topic in resolvedTopics {
                    topicMap[resource.playableTrackId, default: []].insert(topic)
                }
            }
        } catch {
            AppLogger.warning("MeditationModeViewModel: 助眠解压时间场景加载失败 - \(error.localizedDescription)")
        }

        return MeditationSatiCollection(
            resources: resources,
            topicMap: topicMap,
            tagsByTag: tagsByTag,
            scene: scene
        )
    }

    // MARK: - 电台搜索与排序

    /// 分页搜索电台，最多翻 `maxSearchPagesPerQuery` 页。
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

    private func deduplicateSatiResources(_ resources: [SatiResource]) -> [SatiResource] {
        var seen = Set<Int>()
        return resources.filter { resource in
            let key = resource.playableTrackId
            guard key > 0 else { return false }
            return seen.insert(key).inserted
        }
    }

    private func rankRadios(_ radios: [RadioStation]) -> [RadioStation] {
        radios.sorted { lhs, rhs in
            score(lhs) > score(rhs)
        }
    }

    /// 电台相关度打分：命中冥想类关键词每个 +80，另叠加订阅数与节目数的封顶加成。
    private func score(_ radio: RadioStation) -> Int {
        let text = [radio.name, radio.desc ?? "", radio.category ?? ""]
            .joined(separator: " ")
            .lowercased()
        let keywords = ["冥想", "正念", "静心", "专注", "注意力", "集中", "学习", "工作", "轻音乐", "纯音乐", "治愈", "音乐", "呼吸", "睡眠", "助眠", "解压", "减压", "放松", "白噪音", "自然", "雨声"]
        let keywordScore = keywords.reduce(0) { total, keyword in
            total + (text.contains(keyword) ? 80 : 0)
        }
        return keywordScore + min(radio.subCount ?? 0, 100_000) / 1_000 + min(radio.programCount ?? 0, 1_000) / 10
    }

    // MARK: - 列表项构造

    private func makeRadioItem(_ radio: RadioStation) -> MeditationContentItem {
        let subtitle = (radio.desc?.isEmpty == false ? radio.desc : nil)
            ?? radio.dj?.nickname
            ?? String(localized: "podcast_title")

        return MeditationContentItem(
            id: "radio-\(radio.id)",
            title: radio.name,
            subtitle: subtitle,
            detail: radio.programCount.map { String(format: String(localized: "podcast_episode_count"), $0) },
            coverURL: radio.coverUrl,
            category: radio.category,
            source: .radio(radio)
        )
    }

    private func makeSatiItem(_ resource: SatiResource) -> MeditationContentItem {
        let tag = resource.category.flatMap { satiTagsByTag[$0] }
        let category = tag?.tagDesc ?? resource.categoryTitle
        let subtitle = tag?.text ?? satiScene?.text ?? String(localized: "meditation_sati_source")

        return MeditationContentItem(
            id: "sati-\(resource.playableTrackId)",
            title: resource.name,
            subtitle: subtitle,
            detail: nil,
            coverURL: resource.coverUrl,
            category: category,
            source: .sati(resource)
        )
    }

    private func satiPlaybackContext(for resource: SatiResource) -> [SatiResource] {
        let scopedResources = visibleSatiResources
        if scopedResources.contains(where: { $0.playableTrackId == resource.playableTrackId }) {
            return scopedResources
        }
        return [resource] + scopedResources
    }

    /// Sati 分类标签到冥想主题的静态映射。
    private static func topics(forSatiTag tag: String?) -> Set<MeditationTopic> {
        switch tag {
        case "sleep", "starGoodNight", "goodnightStory":
            return [.sleep]
        case "meditation":
            return [.mindfulness, .breathing]
        case "lightmusic", "naturalMusic":
            return [.lightMusic]
        case "cloudStudyRoom":
            return [.focus]
        case "relax":
            return [.relax]
        case "dokodemo":
            return [.ambient, .lightMusic]
        default:
            return []
        }
    }

    private static func makeTagMap(_ tags: [SatiTag]) -> [String: SatiTag] {
        var result: [String: SatiTag] = [:]
        for tag in tags {
            result[tag.tag] = tag
        }
        return result
    }
}

/// 整体结果的磁盘缓存快照。
private struct MeditationModeCacheSnapshot: Codable {
    let radios: [RadioStation]
    let radioTopics: [Int: Set<MeditationTopic>]
    let satiResources: [SatiResource]
    let satiResourceTopics: [Int: Set<MeditationTopic>]
    let satiTags: [SatiTag]
    let satiScene: SatiScene?
}

/// 单次 Sati 拉取的中间结果集。
private struct MeditationSatiCollection {
    let resources: [SatiResource]
    let topicMap: [Int: Set<MeditationTopic>]
    let tagsByTag: [String: SatiTag]
    let scene: SatiScene?
}
