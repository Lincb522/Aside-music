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
    
    var isLoading = false
    var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    func fetchData() {
        isLoading = true
        errorMessage = nil

        let personalizePublisher = apiService.fetchDJPersonalizeRecommend(limit: 6)
            .catch { _ in Just([RadioStation]()) }
        let categoriesPublisher = apiService.fetchDJCategories()
            .catch { _ in Just([RadioCategory]()) }
        let recommendPublisher = apiService.fetchDJRecommend()
            .catch { _ in Just([RadioStation]()) }
        let broadcastPublisher = apiService.fetchBroadcastChannels(limit: 6)
            .catch { _ in Just([BroadcastChannel]()) }

        Publishers.Zip4(personalizePublisher, categoriesPublisher, recommendPublisher, broadcastPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] personalized, cats, recommend, broadcasts in
                self?.personalizedRadios = personalized
                self?.categories = cats
                self?.recommendRadios = recommend
                self?.broadcastChannels = broadcasts
                self?.isLoading = false
                // 加载扩展数据
                self?.fetchExtendedData()
            }
            .store(in: &cancellables)
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
