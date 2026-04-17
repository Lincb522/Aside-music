import Foundation
import Observation
import Combine

@MainActor
@Observable class PodcastViewModel {
    var personalizedRadios: [RadioStation] = []
    var categories: [RadioCategory] = []
    var recommendRadios: [RadioStation] = []
    var broadcastChannels: [BroadcastChannel] = []
    
    // DJ 扩展数据
    var djBanners: [Banner] = []
    var paygiftRadios: [RadioStation] = []
    var newcomerRadios: [RadioStation] = []
    var programToplist: [RadioProgram] = []
    var todayPerfered: [RadioStation] = []
    var hotRadios: [RadioStation] = []

    // 播客首页 Tab 真实数据
    var rcmdPrograms: [PodcastCreative] = []      // 为你推荐（节目）
    var hotPodcasts: [PodcastCreative] = []        // 热门播客（电台）
    var newestPrograms: [PodcastCreative] = []     // 上新佳作
    var chartPrograms: [PodcastCreative] = []      // 音乐播客榜
    
    var isLoading = false
    var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    func fetchData() {
        isLoading = true
        errorMessage = nil

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
                self.categories = cats
                self.broadcastChannels = broadcasts
                self.parsePodcastHomeTab(homeTab)
                self.isLoading = false
                self.fetchExtendedData()
            }
            .store(in: &cancellables)
    }

    /// 解析播客首页 Tab 数据到各个区块
    private func parsePodcastHomeTab(_ response: PodcastHomeTabResponse) {
        guard let blocks = response.data?.blockVOS else { return }
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
    private func fetchExtendedData() {
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
                self?.djBanners = first.0
                self?.paygiftRadios = first.1
                self?.newcomerRadios = first.2
                self?.programToplist = second.0
                self?.todayPerfered = second.1
            }
            .store(in: &cancellables)
    }

    func refreshData() {
        fetchData()
    }
}
