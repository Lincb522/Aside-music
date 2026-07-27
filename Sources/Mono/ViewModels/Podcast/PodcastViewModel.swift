import Foundation
import Combine

@MainActor
class PodcastViewModel: ObservableObject {
    static let shared = PodcastViewModel()

    @Published var personalizedRadios: [RadioStation] = []
    @Published var categories: [RadioCategory] = []
    @Published var recommendRadios: [RadioStation] = []
    @Published var broadcastChannels: [BroadcastChannel] = []
    
    // DJ 扩展数据
    @Published var djBanners: [Banner] = []
    @Published var paygiftRadios: [RadioStation] = []
    @Published var newcomerRadios: [RadioStation] = []
    @Published var programToplist: [RadioProgram] = []
    @Published var todayPerfered: [RadioStation] = []
    @Published var hotRadios: [RadioStation] = []

    // 播客首页 Tab 真实数据
    @Published var rcmdPrograms: [PodcastCreative] = []      // 为你推荐（节目）
    @Published var hotPodcasts: [PodcastCreative] = []        // 热门播客（电台）
    @Published var newestPrograms: [PodcastCreative] = []     // 上新佳作
    @Published var chartPrograms: [PodcastCreative] = []      // 音乐播客榜
    
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private enum CacheKey {
        static let personalizedRadios = "podcast_personalized_radios"
        static let categories = "podcast_categories"
        static let recommendRadios = "podcast_recommend_radios"
        static let broadcastChannels = "podcast_broadcast_channels"
        static let djBanners = "podcast_dj_banners"
        static let paygiftRadios = "podcast_paygift_radios"
        static let newcomerRadios = "podcast_newcomer_radios"
        static let programToplist = "podcast_program_toplist"
        static let todayPreferred = "podcast_today_preferred"
        static let hotRadios = "podcast_hot_radios"
        static let rcmdPrograms = "podcast_rcmd_programs"
        static let hotPodcasts = "podcast_hot_podcasts"
        static let newestPrograms = "podcast_newest_programs"
        static let chartPrograms = "podcast_chart_programs"
    }

    var hasDisplayableContent: Bool {
        !personalizedRadios.isEmpty
            || !categories.isEmpty
            || !recommendRadios.isEmpty
            || !broadcastChannels.isEmpty
            || !rcmdPrograms.isEmpty
            || !hotPodcasts.isEmpty
            || !newestPrograms.isEmpty
            || !chartPrograms.isEmpty
    }

    func ensureDataLoaded(reason: String = "podcast appear") {
        loadCache()
        guard !isLoading else { return }

        let shouldRefreshDaily = GlobalRefreshManager.shared.checkDailyRefreshNeeded(for: .podcast)
        guard shouldRefreshDaily || !hasDisplayableContent else { return }

        fetchData(
            forceDaily: shouldRefreshDaily,
            marksDailyRefresh: shouldRefreshDaily,
            reason: reason
        )
    }

    func preloadIfNeeded(forceDaily: Bool, reason: String) {
        loadCache()
        guard !isLoading else { return }
        guard forceDaily || !hasDisplayableContent else { return }

        fetchData(
            forceDaily: forceDaily,
            marksDailyRefresh: forceDaily,
            reason: reason
        )
    }

    func fetchData(
        forceDaily: Bool = false,
        marksDailyRefresh: Bool = false,
        reason: String = "podcast fetch"
    ) {
        guard !isLoading else {
            AppLogger.debug("PodcastViewModel: 播客数据正在加载，跳过重复请求 - \(reason)")
            return
        }

        loadCache()
        isLoading = true
        errorMessage = nil
        AppLogger.debug("PodcastViewModel: 加载播客数据 - \(reason) forceDaily=\(forceDaily)")

        // 并行拉取分类、广播频道和播客首页 Tab
        let categoriesPublisher = apiService.fetchDJCategories()
            .catch { _ in Just([RadioCategory]()) }
        let broadcastPublisher = apiService.fetchBroadcastChannels(limit: 6)
            .catch { _ in Just([BroadcastChannel]()) }
        let homeTabPublisher = apiService.fetchPodcastHomeTab()
            .catch { _ in Just(PodcastHomeTabResponse(code: -1, data: nil)) }

        Publishers.Zip3(categoriesPublisher, broadcastPublisher, homeTabPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cats, broadcasts, homeTab in
                guard let self = self else { return }
                let hasCategoriesPayload = !cats.isEmpty
                let hasBroadcastPayload = !broadcasts.isEmpty
                let hasHomeTabPayload = homeTab.data?.blockVOS?.contains {
                    !($0.creatives?.isEmpty ?? true)
                } ?? false

                if hasCategoriesPayload {
                    self.assignIfIdentityChanged(cats, to: &self.categories) { $0.id }
                }
                if hasBroadcastPayload {
                    self.assignIfIdentityChanged(broadcasts, to: &self.broadcastChannels) { $0.id }
                }
                if hasHomeTabPayload {
                    self.parsePodcastHomeTab(homeTab)
                }
                if hasCategoriesPayload || hasBroadcastPayload || hasHomeTabPayload {
                    self.storeCoreCache()
                }
                self.fetchExtendedData(marksDailyRefresh: marksDailyRefresh)
            }
            .store(in: &cancellables)
    }

    /// 解析播客首页 Tab 数据到各个区块
    private func parsePodcastHomeTab(_ response: PodcastHomeTabResponse) {
        guard let blocks = response.data?.blockVOS else { return }

        rcmdPrograms = []
        hotPodcasts = []
        newestPrograms = []
        chartPrograms = []
        personalizedRadios = []
        hotRadios = []
        recommendRadios = []

        for block in blocks {
            guard let code = block.blockCode, let creatives = block.creatives else { continue }
            switch code {
            case "RCMD_FOR_YOU":
                rcmdPrograms = creatives
                // 兼容：从推荐节目中提取电台作为 personalizedRadios
                personalizedRadios = creatives.compactMap { c -> RadioStation? in
                    guard let djProg = c.creativeExtInfoVO?.djProgram,
                          let radio = djProg.radio else { return nil }
                    return RadioStation(
                        id: radio.id ?? djProg.id,
                        name: radio.name ?? djProg.name ?? "",
                        picUrl: radio.picUrl ?? c.uiElement?.image?.imageUrl,
                        dj: djProg.dj,
                        programCount: nil, subCount: nil, desc: nil,
                        categoryId: nil, category: nil
                    )
                }
            case "HOTTEST_VOICELIST_BLOCK":
                hotPodcasts = creatives
                // 兼容旧 UI：提取电台列表
                hotRadios = creatives.compactMap { $0.creativeExtInfoVO?.radio }
                recommendRadios = Array(hotRadios.prefix(6))
            case "NEWEST_GOOD_VOICE_BLOCK":
                newestPrograms = creatives
            case "FINITE_CHARTS_BLOCK":
                if let resources = creatives.first?.resources {
                    chartPrograms = resources.map { $0.asCreative }
                } else {
                    chartPrograms = creatives
                }
            default:
                break
            }
        }
    }
    
    /// 加载 DJ 扩展数据（Banner、付费精品、新人榜、节目榜、今日优选）
    private func fetchExtendedData(marksDailyRefresh: Bool) {
        let bannerPub = apiService.fetchDJBanner()
            .catch { _ in Just([Banner]()) }
        let paygiftPub = apiService.fetchDJPaygift(limit: 6)
            .catch { _ in Just([RadioStation]()) }
        let newcomerPub = apiService.fetchDJToplistNewcomer(limit: 6)
            .catch { _ in Just([RadioStation]()) }
        let programPub = apiService.fetchDJProgramToplist(limit: 10)
            .catch { _ in Just([RadioProgram]()) }
        let todayPub = apiService.fetchDJTodayPerfered()
            .catch { _ in Just([RadioStation]()) }
        
        Publishers.Zip3(bannerPub, paygiftPub, newcomerPub)
            .combineLatest(Publishers.Zip(programPub, todayPub))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] first, second in
                guard let self else { return }

                let hasExtendedPayload = !first.0.isEmpty
                    || !first.1.isEmpty
                    || !first.2.isEmpty
                    || !second.0.isEmpty
                    || !second.1.isEmpty

                if !first.0.isEmpty {
                    self.assignIfIdentityChanged(first.0, to: &self.djBanners) { $0.id }
                }
                if !first.1.isEmpty {
                    self.assignIfIdentityChanged(first.1, to: &self.paygiftRadios) { $0.id }
                }
                if !first.2.isEmpty {
                    self.assignIfIdentityChanged(first.2, to: &self.newcomerRadios) { $0.id }
                }
                if !second.0.isEmpty {
                    self.assignIfIdentityChanged(second.0, to: &self.programToplist) { $0.id }
                }
                if !second.1.isEmpty {
                    self.assignIfIdentityChanged(second.1, to: &self.todayPerfered) { $0.id }
                }
                if hasExtendedPayload {
                    self.storeExtendedCache()
                }

                self.isLoading = false
                if marksDailyRefresh {
                    GlobalRefreshManager.shared.markDailyRefreshCompleted(for: .podcast)
                }
            }
            .store(in: &cancellables)
    }

    func refreshData() {
        fetchData(forceDaily: true, marksDailyRefresh: true, reason: "podcast manual refresh")
    }

    private func loadCache() {
        let cache = OptimizedCacheManager.shared

        if let cached = cache.getObject(forKey: CacheKey.personalizedRadios, type: [RadioStation].self) {
            assignIfIdentityChanged(cached, to: &personalizedRadios) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.categories, type: [RadioCategory].self) {
            assignIfIdentityChanged(cached, to: &categories) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.recommendRadios, type: [RadioStation].self) {
            assignIfIdentityChanged(cached, to: &recommendRadios) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.broadcastChannels, type: [BroadcastChannel].self) {
            assignIfIdentityChanged(cached, to: &broadcastChannels) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.djBanners, type: [Banner].self) {
            assignIfIdentityChanged(cached, to: &djBanners) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.paygiftRadios, type: [RadioStation].self) {
            assignIfIdentityChanged(cached, to: &paygiftRadios) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.newcomerRadios, type: [RadioStation].self) {
            assignIfIdentityChanged(cached, to: &newcomerRadios) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.programToplist, type: [RadioProgram].self) {
            assignIfIdentityChanged(cached, to: &programToplist) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.todayPreferred, type: [RadioStation].self) {
            assignIfIdentityChanged(cached, to: &todayPerfered) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.hotRadios, type: [RadioStation].self) {
            assignIfIdentityChanged(cached, to: &hotRadios) { $0.id }
        }
        if let cached = cache.getObject(forKey: CacheKey.rcmdPrograms, type: [PodcastCreative].self) {
            assignIfIdentityChanged(cached, to: &rcmdPrograms, id: podcastCreativeIdentity)
        }
        if let cached = cache.getObject(forKey: CacheKey.hotPodcasts, type: [PodcastCreative].self) {
            assignIfIdentityChanged(cached, to: &hotPodcasts, id: podcastCreativeIdentity)
        }
        if let cached = cache.getObject(forKey: CacheKey.newestPrograms, type: [PodcastCreative].self) {
            assignIfIdentityChanged(cached, to: &newestPrograms, id: podcastCreativeIdentity)
        }
        if let cached = cache.getObject(forKey: CacheKey.chartPrograms, type: [PodcastCreative].self) {
            assignIfIdentityChanged(cached, to: &chartPrograms, id: podcastCreativeIdentity)
        }
    }

    private func storeCoreCache() {
        let cache = OptimizedCacheManager.shared
        cache.setObject(personalizedRadios, forKey: CacheKey.personalizedRadios)
        cache.setObject(categories, forKey: CacheKey.categories)
        cache.setObject(recommendRadios, forKey: CacheKey.recommendRadios)
        cache.setObject(broadcastChannels, forKey: CacheKey.broadcastChannels)
        cache.setObject(hotRadios, forKey: CacheKey.hotRadios)
        cache.setObject(rcmdPrograms, forKey: CacheKey.rcmdPrograms)
        cache.setObject(hotPodcasts, forKey: CacheKey.hotPodcasts)
        cache.setObject(newestPrograms, forKey: CacheKey.newestPrograms)
        cache.setObject(chartPrograms, forKey: CacheKey.chartPrograms)
    }

    private func storeExtendedCache() {
        let cache = OptimizedCacheManager.shared
        cache.setObject(djBanners, forKey: CacheKey.djBanners)
        cache.setObject(paygiftRadios, forKey: CacheKey.paygiftRadios)
        cache.setObject(newcomerRadios, forKey: CacheKey.newcomerRadios)
        cache.setObject(programToplist, forKey: CacheKey.programToplist)
        cache.setObject(todayPerfered, forKey: CacheKey.todayPreferred)
    }

    private func assignIfIdentityChanged<Element, ID: Equatable>(
        _ cached: [Element],
        to target: inout [Element],
        id: (Element) -> ID
    ) {
        guard !hasSameIdentity(target, cached, id: id) else { return }
        target = cached
    }

    private func hasSameIdentity<Element, ID: Equatable>(
        _ lhs: [Element],
        _ rhs: [Element],
        id: (Element) -> ID
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { id($0) == id($1) }
    }

    private func podcastCreativeIdentity(_ creative: PodcastCreative) -> String {
        var parts: [String] = []
        if let creativeId = creative.creativeId {
            parts.append(creativeId)
        }
        if let title = creative.uiElement?.mainTitle?.title {
            parts.append(title)
        }
        if let programId = creative.creativeExtInfoVO?.djProgram?.id {
            parts.append(String(programId))
        }
        if let radioId = creative.creativeExtInfoVO?.radio?.id {
            parts.append(String(radioId))
        }
        return parts.joined(separator: "-")
    }
}
