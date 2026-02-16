import Foundation
import Combine

// MARK: - DailyRecommendViewModel

@MainActor
class DailyRecommendViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var historyDates: [String] = []
    @Published var showHistorySheet = false
    @Published var isLoadingHistory = false

    @Published var showStyleMenu = false
    @Published var noHistoryMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let api = APIService.shared
    private let styleManager = StyleManager.shared

    init() {
        refreshContent()

        styleManager.$currentStyle
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                AppLogger.debug("DailyRecommendViewModel - Style changed to: \(style?.finalName ?? "Default")")
                self?.refreshContent()
            }
            .store(in: &cancellables)
    }

    func refreshContent() {
        if let style = styleManager.currentStyle {
            loadStyleSongs(style: style)
        } else {
            loadStandardRecommend()
        }
    }

    func loadStandardRecommend() {
        isLoading = true
        errorMessage = nil

        api.fetchDailySongs(cachePolicy: .staleWhileRevalidate, ttl: 3600)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] songs in
                self?.songs = songs
                self?.isLoading = false
            })
            .store(in: &cancellables)
    }

    private func loadStyleSongs(style: APIService.StyleTag) {
        isLoading = true
        errorMessage = nil

        AppLogger.debug("Loading songs for style: \(style.finalName) (ID: \(style.finalId))")
        api.fetchStyleSongs(tagId: style.finalId)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Style Songs Error: \(error)")
                    self?.errorMessage = "Songs Error: \(error.localizedDescription)"
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] songs in
                AppLogger.debug("Received \(songs.count) songs for style \(style.finalName)")
                self?.songs = songs
                self?.isLoading = false
            })
            .store(in: &cancellables)
    }

    func loadHistoryDates() {
        isLoadingHistory = true
        noHistoryMessage = nil
        AppLogger.debug("Loading history recommend dates...")
        api.fetchHistoryRecommendDates()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingHistory = false
                if case .failure(let error) = completion {
                    AppLogger.error("History dates load error: \(error)")
                    self?.noHistoryMessage = "加载失败，请稍后重试"
                }
            }, receiveValue: { [weak self] dates in
                AppLogger.debug("Received history dates: \(dates)")
                self?.historyDates = dates
                self?.isLoadingHistory = false
                if !dates.isEmpty {
                    AppLogger.debug("Setting showHistorySheet = true")
                    self?.showHistorySheet = true
                    AppLogger.debug("showHistorySheet is now: \(self?.showHistorySheet ?? false)")
                } else {
                    AppLogger.debug("History dates is empty")
                    self?.noHistoryMessage = "暂无历史推荐记录，明天再来看看吧"
                }
            })
            .store(in: &cancellables)
    }
}
